import {
  getAnnouncements,
  getAttendance,
  getClassroomSchedule,
  getGrades,
  getMaterialsByClassroom,
  getMyStudent,
  getStudentClassrooms,
  getStudentSubmissions,
  getSubject,
} from '@/lib/api';
import { getUser } from '@/lib/auth';

export function toArray(value) {
  if (Array.isArray(value)) return value;
  if (Array.isArray(value?.items)) return value.items;
  return [];
}

export function uniqueBy(items, getKey) {
  const seen = new Set();
  return items.filter((item) => {
    const key = getKey(item);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export function formatNumber(value, options) {
  return new Intl.NumberFormat(undefined, options).format(value ?? 0);
}

export function formatPercent(value, digits = 0) {
  if (!Number.isFinite(value)) return '--';
  return `${value.toFixed(digits)}%`;
}

export function formatDate(value, options = {}) {
  if (!value) return 'Not available';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not available';
  return date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    ...options,
  });
}

export function formatDateTime(value, options = {}) {
  if (!value) return 'Not available';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not available';
  return date.toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
    ...options,
  });
}

export function formatRelativeTime(value) {
  if (!value) return 'Just now';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Just now';

  const diffMs = date.getTime() - Date.now();
  const diffMinutes = Math.round(diffMs / 60000);
  const ranges = [
    ['year', 525600],
    ['month', 43800],
    ['week', 10080],
    ['day', 1440],
    ['hour', 60],
    ['minute', 1],
  ];
  const rtf = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' });

  for (const [unit, size] of ranges) {
    if (Math.abs(diffMinutes) >= size || unit === 'minute') {
      return rtf.format(Math.round(diffMinutes / size), unit);
    }
  }

  return 'Just now';
}

export function parseTimeParts(value) {
  if (!value) return [0, 0];
  const parts = String(value).split(':').map(Number);
  return [parts[0] ?? 0, parts[1] ?? 0];
}

export function formatTime(value) {
  const [hours, minutes] = parseTimeParts(value);
  const date = new Date();
  date.setHours(hours, minutes, 0, 0);
  return date.toLocaleTimeString(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  });
}

export function formatTimeRange(startTime, endTime) {
  return `${formatTime(startTime)} - ${formatTime(endTime)}`;
}

export function scoreToLetter(score) {
  const value = Number(score ?? 0);
  if (value >= 90) return 'A';
  if (value >= 80) return 'B';
  if (value >= 70) return 'C';
  if (value >= 60) return 'D';
  return 'F';
}

export function scoreToGpa(score) {
  const value = Number(score ?? 0);
  if (value >= 93) return 4.0;
  if (value >= 90) return 3.7;
  if (value >= 87) return 3.3;
  if (value >= 83) return 3.0;
  if (value >= 80) return 2.7;
  if (value >= 77) return 2.3;
  if (value >= 73) return 2.0;
  if (value >= 70) return 1.7;
  if (value >= 67) return 1.3;
  if (value >= 63) return 1.0;
  if (value >= 60) return 0.7;
  return 0;
}

export function calculateGpa(grades = []) {
  if (!grades.length) return 0;
  const total = grades.reduce((sum, grade) => sum + scoreToGpa(grade.score), 0);
  return total / grades.length;
}

export function calculateMedian(values = []) {
  if (!values.length) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
  return sorted[middle];
}

export function calculateAttendanceSummary(records = []) {
  const summary = records.reduce(
    (accumulator, record) => {
      const status = String(record?.status ?? '').toLowerCase();
      accumulator.total += 1;
      if (status === 'present') accumulator.present += 1;
      if (status === 'absent') accumulator.absent += 1;
      if (status === 'late') accumulator.late += 1;
      return accumulator;
    },
    { total: 0, present: 0, absent: 0, late: 0 },
  );

  summary.rate = summary.total ? (summary.present / summary.total) * 100 : 0;
  return summary;
}

export function buildGradeTrend(grades = []) {
  const semesterMap = new Map();

  grades.forEach((grade) => {
    const semester = grade?.semester || 'Current term';
    const entry = semesterMap.get(semester) ?? { label: semester, total: 0, count: 0 };
    entry.total += Number(grade?.score ?? 0);
    entry.count += 1;
    semesterMap.set(semester, entry);
  });

  return [...semesterMap.values()].map((entry) => ({
    label: entry.label,
    value: entry.count ? scoreToGpa(entry.total / entry.count) : 0,
  }));
}

export function buildAttendanceTrend(records = []) {
  const monthMap = new Map();

  records.forEach((record) => {
    const date = new Date(record?.date ?? record?.createdAt ?? '');
    if (Number.isNaN(date.getTime())) return;

    const label = date.toLocaleDateString(undefined, { month: 'short', year: 'numeric' });
    const entry = monthMap.get(label) ?? { label, total: 0, present: 0 };
    entry.total += 1;
    if (String(record?.status ?? '').toLowerCase() === 'present') {
      entry.present += 1;
    }
    monthMap.set(label, entry);
  });

  return [...monthMap.values()].map((entry) => ({
    label: entry.label,
    value: entry.total ? (entry.present / entry.total) * 100 : 0,
  }));
}

export function getMaterialTypeLabel(type) {
  const value = Number(type ?? 0);
  if (value === 1) return 'Slide';
  if (value === 2) return 'Assignment';
  if (value === 3) return 'Link';
  if (value === 4) return 'Reference';
  return 'Resource';
}

export function getMaterialTypeTone(type) {
  const value = Number(type ?? 0);
  if (value === 2) return 'warning';
  if (value === 3) return 'info';
  if (value === 4) return 'neutral';
  return 'success';
}

export function getSubmissionStatus(submission) {
  if (!submission) return 'Pending';
  if (submission.grade !== null && submission.grade !== undefined) return 'Graded';
  return 'Submitted';
}

export function getAttendanceTone(rate) {
  if (rate < 75) return 'danger';
  if (rate < 90) return 'warning';
  return 'success';
}

export function getScoreTone(score) {
  const value = Number(score ?? 0);
  if (value < 60) return 'danger';
  if (value < 75) return 'warning';
  return 'success';
}

export function getInitials(student, user) {
  const first = student?.firstName || user?.firstName || 'S';
  const last = student?.lastName || user?.lastName || 'T';
  return `${first[0] ?? 'S'}${last[0] ?? 'T'}`.toUpperCase();
}

export function getDisplayName(student, user) {
  const fullName = `${student?.firstName ?? user?.firstName ?? ''} ${student?.lastName ?? user?.lastName ?? ''}`.trim();
  return fullName || user?.email?.split('@')[0] || 'Student';
}

export function safeFilename(value, fallback = 'download') {
  return String(value || fallback)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80) || fallback;
}

export function downloadTextFile(filename, content, mimeType = 'text/plain;charset=utf-8') {
  if (typeof window === 'undefined') return;
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

export function exportCsv(filename, headers, rows) {
  const csv = [
    headers.join(','),
    ...rows.map((row) =>
      row
        .map((value) => `"${String(value ?? '').replaceAll('"', '""')}"`)
        .join(','),
    ),
  ].join('\n');

  downloadTextFile(filename, csv, 'text/csv;charset=utf-8');
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

export function openPrintableTranscript(student, grades) {
  if (typeof window === 'undefined') return;

  const name = escapeHtml(getDisplayName(student, {}));
  const htmlRows = grades
    .map(
      (grade) => `
        <tr>
          <td>${escapeHtml(grade.subjectName)}</td>
          <td>${escapeHtml(grade.semester)}</td>
          <td>${escapeHtml(Number(grade.score ?? 0).toFixed(1))}</td>
          <td>${escapeHtml(scoreToLetter(grade.score))}</td>
          <td>${escapeHtml(scoreToGpa(grade.score).toFixed(1))}</td>
        </tr>`,
    )
    .join('');

  const printable = window.open('', '_blank', 'width=960,height=720');
  if (!printable) return;

  printable.document.write(`
    <html>
      <head>
        <title>${name} Transcript</title>
        <style>
          body { font-family: Arial, sans-serif; padding: 32px; color: #111827; }
          h1 { margin: 0 0 8px; }
          p { color: #4b5563; }
          table { width: 100%; border-collapse: collapse; margin-top: 24px; }
          th, td { border: 1px solid #d1d5db; padding: 12px; text-align: left; }
          th { background: #f3f4f6; }
        </style>
      </head>
      <body>
        <h1>${name}</h1>
        <p>Generated ${escapeHtml(formatDateTime(new Date().toISOString()))}</p>
        <table>
          <thead>
            <tr>
              <th>Subject</th>
              <th>Semester</th>
              <th>Score</th>
              <th>Letter</th>
              <th>GPA</th>
            </tr>
          </thead>
          <tbody>${htmlRows}</tbody>
        </table>
      </body>
    </html>
  `);
  printable.document.close();
  printable.focus();
  printable.print();
}

function combineDateAndTime(date, timeValue) {
  const target = new Date(date);
  const [hours, minutes] = parseTimeParts(timeValue);
  target.setHours(hours, minutes, 0, 0);
  return target;
}

function scheduleDayToJs(dayOfWeek) {
  const value = Number(dayOfWeek ?? 1);
  return value === 7 ? 0 : value;
}

export function buildScheduleOccurrences(schedules = [], classrooms = [], rangeStart, rangeEnd) {
  const start = new Date(rangeStart);
  const end = new Date(rangeEnd);
  const classroomMap = new Map(classrooms.map((classroom) => [classroom.id, classroom]));
  const occurrences = [];

  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return occurrences;
  }

  schedules.forEach((schedule) => {
    const jsDay = scheduleDayToJs(schedule?.dayOfWeek);
    const cursor = new Date(start);
    cursor.setHours(0, 0, 0, 0);

    while (cursor <= end) {
      if (cursor.getDay() === jsDay) {
        const occurrenceStart = combineDateAndTime(cursor, schedule.startTime);
        const occurrenceEnd = combineDateAndTime(cursor, schedule.endTime);

        if (occurrenceEnd >= start && occurrenceStart <= end) {
          const classroom = classroomMap.get(schedule.classroomId);
          occurrences.push({
            ...schedule,
            classroomName: schedule.classroomName ?? classroom?.name ?? 'Classroom',
            roomName: classroom?.roomName ?? 'Room not assigned',
            start: occurrenceStart,
            end: occurrenceEnd,
          });
        }
      }
      cursor.setDate(cursor.getDate() + 1);
    }
  });

  return occurrences.sort((left, right) => left.start - right.start);
}

export function buildUpcomingScheduleItems(schedules = [], classrooms = [], limit = 6) {
  const now = new Date();
  const future = new Date(now);
  future.setDate(future.getDate() + 21);

  return buildScheduleOccurrences(schedules, classrooms, now, future).slice(0, limit);
}

function formatIcsDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  return `${year}${month}${day}T${hours}${minutes}${seconds}`;
}

export function downloadScheduleIcs(student, occurrences) {
  const events = occurrences
    .map(
      (occurrence) => [
        'BEGIN:VEVENT',
        `UID:${occurrence.id}-${occurrence.start.toISOString()}`,
        `DTSTAMP:${formatIcsDate(new Date())}`,
        `DTSTART:${formatIcsDate(occurrence.start)}`,
        `DTEND:${formatIcsDate(occurrence.end)}`,
        `SUMMARY:${occurrence.subjectName} - ${occurrence.classroomName}`,
        `LOCATION:${occurrence.roomName}`,
        `DESCRIPTION:${occurrence.teacherName ?? 'Teacher not assigned'}`,
        'END:VEVENT',
      ].join('\n'),
    )
    .join('\n');

  const content = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//School Management//Student Schedule//EN', events, 'END:VCALENDAR'].join('\n');
  downloadTextFile(`${safeFilename(getDisplayName(student, {}), 'student')}-schedule.ics`, content, 'text/calendar;charset=utf-8');
}

export async function resolveCurrentStudentProfile() {
  const user = getUser();
  if (!user) return { user: null, student: null };

  const student = await getMyStudent();
  return { user, student };
}

export async function loadStudentBaseData() {
  const { user, student } = await resolveCurrentStudentProfile();
  if (!student) {
    return { user, student: null, classrooms: [] };
  }

  const classrooms = toArray(await getStudentClassrooms(student.id));
  return { user, student, classrooms };
}

export async function loadStudentSubjects(classrooms = []) {
  const subjectIds = uniqueBy(classrooms, (classroom) => classroom.subjectId)
    .map((classroom) => classroom.subjectId)
    .filter(Boolean);

  const results = await Promise.allSettled(subjectIds.map((subjectId) => getSubject(subjectId)));
  return results
    .filter((result) => result.status === 'fulfilled' && result.value)
    .map((result) => result.value);
}

export async function loadStudentSchedules(classrooms = []) {
  const results = await Promise.allSettled(
    classrooms.map(async (classroom) => ({
      classroomId: classroom.id,
      classroom,
      items: toArray(await getClassroomSchedule(classroom.id)),
    })),
  );

  return results.flatMap((result) => {
    if (result.status !== 'fulfilled') return [];
    const { classroom, items } = result.value;
    return items.map((item) => ({
      ...item,
      classroomId: item.classroomId ?? classroom.id,
      classroomName: item.classroomName ?? classroom.name,
      roomName: classroom.roomName,
    }));
  });
}

export async function loadStudentMaterials(classrooms = []) {
  const results = await Promise.allSettled(
    classrooms.map(async (classroom) => ({
      classroom,
      items: toArray(await getMaterialsByClassroom(classroom.id)),
    })),
  );

  return results.flatMap((result) => {
    if (result.status !== 'fulfilled') return [];
    const { classroom, items } = result.value;
    return items.map((item) => ({
      ...item,
      classroomName: classroom.name,
      subjectId: classroom.subjectId,
      subjectName: classroom.subjectName,
      teacherName: classroom.teacherName,
    }));
  });
}

export async function loadStudentAnnouncements(classrooms = []) {
  const results = await Promise.allSettled(
    classrooms.map(async (classroom) => toArray(await getAnnouncements(classroom.id))),
  );

  return uniqueBy(
    results.flatMap((result) => (result.status === 'fulfilled' ? result.value : [])),
    (announcement) => announcement.id,
  ).sort((left, right) => new Date(right.publishedAt ?? right.createdAt) - new Date(left.publishedAt ?? left.createdAt));
}

export async function loadStudentSubmissions(studentId) {
  if (!studentId) return [];
  return toArray(await getStudentSubmissions(studentId));
}

export async function loadStudentGrades(studentId) {
  if (!studentId) return [];
  return toArray(await getGrades({ studentId }));
}

export async function loadStudentAttendance(studentId) {
  if (!studentId) return [];
  return toArray(await getAttendance({ studentId }));
}

export function getAnnouncementReadStorageKey(studentId) {
  return `student-announcements-read:${studentId}`;
}

export function getReadAnnouncementIds(studentId) {
  if (typeof window === 'undefined' || !studentId) return [];
  try {
    return JSON.parse(localStorage.getItem(getAnnouncementReadStorageKey(studentId)) ?? '[]');
  } catch {
    return [];
  }
}

export function saveReadAnnouncementIds(studentId, ids) {
  if (typeof window === 'undefined' || !studentId) return;
  localStorage.setItem(getAnnouncementReadStorageKey(studentId), JSON.stringify(ids));
}

export function calculatePasswordStrength(password) {
  let score = 0;
  if (password.length >= 8) score += 1;
  if (/[A-Z]/.test(password)) score += 1;
  if (/[a-z]/.test(password)) score += 1;
  if (/\d/.test(password)) score += 1;
  if (/[^A-Za-z0-9]/.test(password)) score += 1;

  if (score <= 2) return { score, label: 'Weak', tone: 'danger' };
  if (score <= 4) return { score, label: 'Medium', tone: 'warning' };
  return { score, label: 'Strong', tone: 'success' };
}

export function validateSubmissionFile(file) {
  if (!file) return 'Choose a file to submit.';
  const allowed = [
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/msword',
    'application/zip',
    'application/x-zip-compressed',
    'image/png',
    'image/jpeg',
    'image/webp',
  ];

  if (!allowed.includes(file.type)) {
    return 'Accepted file types are PDF, DOCX, images, and ZIP.';
  }

  if (file.size > 10 * 1024 * 1024) {
    return 'Each file must be 10MB or smaller.';
  }

  return '';
}
