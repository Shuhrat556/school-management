#!/usr/bin/env python3
"""End-to-end smoke test through admin-web -> gateway -> services, the way a browser calls them.

Read-only by default, so it is safe right after a production deploy. --write adds checks that
change data (re-saving a grade, marking attendance, a rejected double booking) and is meant for
local or test stacks only.

  python3 scripts/smoke_test.py --base http://127.0.0.1:3000          # local stack
  SMOKE_PASSWORD=... python3 scripts/smoke_test.py --base http://HOST:3100

Accounts default to the seed users (README "Default Accounts"); override with SMOKE_ADMIN,
SMOKE_TEACHER, SMOKE_STUDENT and SMOKE_PASSWORD. Exits 1 when any check fails.
Standard library only.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

parser = argparse.ArgumentParser(description="End-to-end smoke test through admin-web.")
parser.add_argument("--base", default="http://127.0.0.1:3000", help="admin-web URL (default %(default)s)")
parser.add_argument("--write", action="store_true", help="also run checks that change data (never on production)")
args = parser.parse_args()

BASE = args.base.rstrip("/")
PASSWORD = os.environ.get("SMOKE_PASSWORD", "Password123!")
results = []


def call(method, path, token=None, body=None, raw=False):
    """Returns (status, parsed body or bytes, lower-cased headers); HTTP errors are returned, not raised."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=20) as res:
            payload, status, headers = res.read(), res.status, res.headers
    except urllib.error.HTTPError as e:
        payload, status, headers = e.read(), e.code, e.headers
    headers = {k.lower(): v for k, v in headers.items()}
    if raw:
        return status, payload, headers
    try:
        return status, (json.loads(payload) if payload else None), headers
    except ValueError:
        return status, payload.decode(errors="replace"), headers


def check(name, condition, detail=""):
    results.append((name, bool(condition)))
    print(f"{'PASS' if condition else 'FAIL'}  {name}" + (f"  [{detail}]" if not condition and detail != "" else ""))
    return bool(condition)


def login(email):
    status, body, _ = call("POST", "/api/auth/authenticate", body={"email": email, "password": PASSWORD})
    if not check(f"sign in {email}", status == 200, f"{status} {body}"):
        sys.exit(1)  # nothing else can run without the accounts
    return body


def read_only_checks():
    status, _, headers = call("GET", "/login", raw=True)
    check("admin-web /login", status == 200, status)
    check("security headers", headers.get("x-frame-options") == "DENY" and headers.get("x-content-type-options") == "nosniff")
    check("no X-Powered-By", "x-powered-by" not in headers)

    status, _, _ = call("POST", "/api/auth/authenticate", body={"email": "nobody@example.invalid", "password": "wrong"})
    check("unknown account is 401", status == 401, status)

    admin = login(os.environ.get("SMOKE_ADMIN", "admin@school.com"))
    teacher = login(os.environ.get("SMOKE_TEACHER", "teacher1@school.com"))
    student = login(os.environ.get("SMOKE_STUDENT", "student1@school.com"))
    ctx = {"admin": admin["token"], "teacher": teacher["token"], "student": student["token"],
           "teacher_user": teacher["userId"], "student_refresh": student["refreshToken"]}

    status, page, _ = call("GET", "/api/school/students?page=1&pageSize=20", ctx["admin"])
    check("admin lists students", status == 200 and len(page.get("items", [])) > 0, status)
    ctx["students"] = [s["id"] for s in page.get("items", [])]
    status, _, _ = call("GET", "/api/school/students?page=1&pageSize=5", ctx["student"])
    check("student cannot list students (403)", status == 403, status)

    status, me, _ = call("GET", "/api/school/students/me", ctx["student"])
    if not check("student /students/me", status == 200 and me and me.get("id"), f"{status} {me}"):
        return ctx
    ctx["student_id"] = sid = me["id"]

    status, grades, _ = call("GET", f"/api/school/grades?studentId={sid}", ctx["teacher"])
    check("teacher reads the student's grades", status == 200, status)
    ctx["grades"] = grades if status == 200 else []
    if ctx["grades"]:
        status, _, _ = call("GET", f"/api/school/grades/{ctx['grades'][0]['id']}/history", ctx["teacher"])
        check("teacher reads a grade history", status == 200, status)
    status, _, _ = call("GET", f"/api/school/grades/changes?studentId={sid}", ctx["admin"])
    check("admin reads the grade audit feed", status == 200, status)
    status, _, _ = call("GET", "/api/school/grades/changes", ctx["teacher"])
    check("teacher cannot read the school-wide feed (403)", status == 403, status)

    status, card, _ = call("GET", f"/api/school/students/{sid}/report-card", ctx["student"])
    check("student report card", status == 200 and isinstance(card, dict) and "gpa" in card, status)
    status, csv, headers = call("GET", f"/api/school/students/{sid}/report-card/csv", ctx["student"], raw=True)
    check("report card CSV", status == 200 and headers.get("content-type", "").startswith("text/csv") and b"Subject,Semester" in csv, status)

    status, _, _ = call("GET", "/api/school/notifications/unread-count", ctx["student"])
    check("student notifications", status == 200, status)

    status, rooms, _ = call("GET", f"/api/school/students/{sid}/classrooms", ctx["student"])
    check("student classrooms", status == 200, status)
    ctx["classroom"] = rooms[0]["id"] if status == 200 and rooms else None
    if ctx["classroom"]:
        status, detail, _ = call("GET", f"/api/school/classrooms/{ctx['classroom']}", ctx["teacher"])
        ctx["roster"] = [s["studentId"] for s in detail.get("students", [])] if status == 200 else []
        check("class roster lists the student", sid in ctx["roster"], f"{status}, {len(ctx['roster'])} students")

    status, logins, _ = call("GET", "/api/auth/logins", ctx["student"])
    check("linked sign-in accounts", status == 200 and "hasPassword" in logins, f"{status} {logins}")
    status, _, _ = call("GET", f"/api/auth/user/{ctx['teacher_user']}", ctx["student"])
    check("student cannot look up a teacher (403)", status == 403, status)

    status, rotated, _ = call("POST", "/api/auth/refresh", body={"refreshToken": ctx["student_refresh"]})
    check("refresh token rotates", status == 200 and rotated["refreshToken"] != ctx["student_refresh"], status)
    status, _, _ = call("POST", "/api/auth/refresh", body={"refreshToken": ctx["student_refresh"]})
    check("an already used refresh token is refused", status == 401, status)
    return ctx


def write_checks(ctx):
    sid = ctx.get("student_id")
    if sid and ctx.get("grades"):
        g = ctx["grades"][0]
        new_score = 77 if float(g["score"]) != 77 else 78
        status, saved, _ = call("POST", "/api/school/grades", ctx["teacher"],
                                {"studentId": sid, "subjectId": g["subjectId"], "score": new_score, "semester": g["semester"]})
        check("teacher re-saves a grade (upsert 200)", status == 200, f"{status} {saved}")
        status, history, _ = call("GET", f"/api/school/grades/{g['id']}/history", ctx["teacher"])
        check("grade history records the change",
              status == 200 and any(h["action"] == "Updated" and float(h["newScore"]) == new_score for h in history), status)
        status, unread, _ = call("GET", "/api/school/notifications/unread-count", ctx["student"])
        check("student is notified of the grade", status == 200 and unread["count"] >= 1, f"{status} {unread}")

    classroom = ctx.get("classroom")
    if sid and classroom:
        status, _, _ = call("POST", "/api/school/attendance/mark", ctx["teacher"],
                            {"classroomId": classroom, "date": "2026-10-02", "records": [{"studentId": sid, "status": 3}]})
        check("teacher marks attendance", status == 200, status)
        outsider = next((s for s in ctx.get("students", []) if s not in ctx.get("roster", [])), None)
        if outsider:
            status, _, _ = call("POST", "/api/school/attendance/mark", ctx["teacher"],
                                {"classroomId": classroom, "date": "2026-10-02", "records": [{"studentId": outsider, "status": 1}]})
            check("attendance for a non-member is 400", status == 400, status)

        status, sessions, _ = call("GET", f"/api/school/schedules?classroomId={classroom}", ctx["teacher"])
        if status == 200 and sessions:
            s0 = sessions[0]
            status, body, _ = call("POST", "/api/school/schedules", ctx["admin"], {
                "classroomId": classroom, "subjectId": s0["subjectId"], "dayOfWeek": s0["dayOfWeek"],
                "startTime": s0["startTime"][:5], "endTime": s0["endTime"][:5]})
            check("double-booked class is 409", status == 409, f"{status} {body}")


context = read_only_checks()
if args.write:
    write_checks(context)

failed = [name for name, ok in results if not ok]
print(f"\n{len(results) - len(failed)}/{len(results)} passed" + ("" if args.write else " (read-only)"))
sys.exit(1 if failed else 0)
