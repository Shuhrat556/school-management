'use client';

import { useEffect, useState } from 'react';
import { BarChart3, CalendarX2, ClipboardCheck, GraduationCap, UsersRound } from 'lucide-react';
import { getGrades, getMyChildren, getStudentAttendanceHistory } from '@/lib/api';
import { getUser } from '@/lib/auth';
import StudentEmptyState from '@/components/StudentEmptyState';
import StudentSectionCard from '@/components/StudentSectionCard';
import StudentStatCard from '@/components/StudentStatCard';
import StudentStatusBadge from '@/components/StudentStatusBadge';
import {
  calculateAttendanceSummary,
  calculateGpa,
  formatDate,
  formatPercent,
  getAttendanceTone,
  getScoreTone,
  scoreToLetter,
  toArray,
} from '@/lib/student-portal';

const toneToStat = { success: 'emerald', warning: 'amber', danger: 'rose' };

async function loadChild(child) {
  const [grades, attendance] = await Promise.all([
    getGrades({ studentId: child.id }),
    getStudentAttendanceHistory(child.id),
  ]);
  return { child, grades: toArray(grades), attendance: toArray(attendance) };
}

function ChildOverview({ child, grades, attendance }) {
  const average = grades.length ? grades.reduce((sum, grade) => sum + Number(grade.score ?? 0), 0) / grades.length : null;
  const summary = calculateAttendanceSummary(attendance);
  const recentGrades = [...grades]
    .sort((left, right) => new Date(right.createdAt) - new Date(left.createdAt))
    .slice(0, 8);
  const missed = [...attendance]
    .filter((record) => ['absent', 'late'].includes(String(record.status).toLowerCase()))
    .sort((left, right) => String(right.date).localeCompare(String(left.date)))
    .slice(0, 5);

  return (
    <StudentSectionCard
      icon={GraduationCap}
      title={`${child.firstName} ${child.lastName}`}
      subtitle={child.email ?? undefined}
    >
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StudentStatCard
          icon={BarChart3}
          label="Average score"
          value={average === null ? '—' : average.toFixed(1)}
          helper={average === null ? 'No grades yet' : `Letter ${scoreToLetter(average)}`}
          tone={average === null ? 'slate' : toneToStat[getScoreTone(average)]}
        />
        <StudentStatCard
          icon={GraduationCap}
          label="GPA"
          value={grades.length ? calculateGpa(grades).toFixed(2) : '—'}
          helper={`${grades.length} graded subject${grades.length === 1 ? '' : 's'}`}
          tone="blue"
        />
        <StudentStatCard
          icon={ClipboardCheck}
          label="Attendance"
          value={summary.total ? formatPercent(summary.rate) : '—'}
          helper={`${summary.present} present of ${summary.total} marked days`}
          tone={summary.total ? toneToStat[getAttendanceTone(summary.rate)] : 'slate'}
        />
        <StudentStatCard
          icon={CalendarX2}
          label="Absences / late"
          value={`${summary.absent} / ${summary.late}`}
          helper="Days missed or arrived late"
          tone={summary.absent > 0 ? 'rose' : 'emerald'}
        />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <div>
          <h3 className="mb-3 text-sm font-semibold text-slate-700">Latest grades</h3>
          {recentGrades.length === 0 ? (
            <p className="text-sm text-slate-400">No grades recorded yet.</p>
          ) : (
            <ul className="divide-y divide-slate-100 rounded-xl border border-slate-200 bg-white">
              {recentGrades.map((grade) => (
                <li key={grade.id} className="flex items-center justify-between gap-3 px-4 py-3">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-slate-800">{grade.subjectName}</p>
                    <p className="text-xs text-slate-500">Semester {grade.semester}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-semibold text-slate-900">{Number(grade.score).toFixed(0)}</span>
                    <StudentStatusBadge label={scoreToLetter(grade.score)} tone={getScoreTone(grade.score)} />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
        <div>
          <h3 className="mb-3 text-sm font-semibold text-slate-700">Recent absences and late arrivals</h3>
          {missed.length === 0 ? (
            <p className="text-sm text-slate-400">Nothing to report.</p>
          ) : (
            <ul className="divide-y divide-slate-100 rounded-xl border border-slate-200 bg-white">
              {missed.map((record) => (
                <li key={record.id} className="flex items-center justify-between gap-3 px-4 py-3">
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-slate-800">{formatDate(record.date)}</p>
                    <p className="truncate text-xs text-slate-500">{record.classroomName ?? 'Class'}</p>
                  </div>
                  <StudentStatusBadge label={record.status} />
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </StudentSectionCard>
  );
}

export default function ParentDashboardPage() {
  const [state, setState] = useState({ loading: true, error: '', user: null, children: [] });

  useEffect(() => {
    let active = true;

    async function load() {
      const children = await getMyChildren();
      if (!active) return;
      const user = getUser();
      if (children === null) {
        setState({ loading: false, error: 'Could not load your children.', user, children: [] });
        return;
      }

      const details = await Promise.all(toArray(children).map(loadChild));
      if (active) setState({ loading: false, error: '', user, children: details });
    }

    load();
    return () => {
      active = false;
    };
  }, []);

  return (
    <div className="space-y-6">
      <div>
        <p className="text-sm font-medium text-slate-500">Parent portal</p>
        <h1 className="text-2xl font-semibold tracking-tight text-slate-950">
          {state.user?.firstName ? `Hello, ${state.user.firstName}` : 'My children'}
        </h1>
      </div>

      {state.loading ? (
        <div className="flex h-40 items-center justify-center">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-300 border-t-slate-700" />
        </div>
      ) : state.error ? (
        <div className="rounded-xl border border-red-100 bg-red-50 p-4 text-sm text-red-700">{state.error}</div>
      ) : state.children.length === 0 ? (
        <StudentEmptyState
          icon={UsersRound}
          title="No children linked yet"
          description="Ask the school administration to link your account to your child's profile."
        />
      ) : (
        state.children.map((details) => <ChildOverview key={details.child.id} {...details} />)
      )}
    </div>
  );
}
