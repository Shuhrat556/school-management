'use client';

import { useEffect, useMemo, useState } from 'react';
import { CalendarDays, ChevronLeft, ChevronRight, Clock3, Download, List } from 'lucide-react';
import { useAuth } from '@/lib/auth';
import StudentEmptyState from '@/components/StudentEmptyState';
import StudentPageShell from '@/components/StudentPageShell';
import StudentSectionCard from '@/components/StudentSectionCard';
import StudentStatusBadge from '@/components/StudentStatusBadge';
import {
  buildScheduleOccurrences,
  downloadScheduleIcs,
  formatDate,
  formatTimeRange,
  loadStudentBaseData,
  loadStudentMaterials,
  loadStudentSchedules,
} from '@/lib/student-portal';

const SUBJECT_COLORS = ['#526d82', '#6a8aa1', '#809eb3', '#97b1c3', '#a96d5b', '#7a8d54'];

function cloneDate(value) {
  return new Date(value.getFullYear(), value.getMonth(), value.getDate());
}

function addDays(value, days) {
  const next = new Date(value);
  next.setDate(next.getDate() + days);
  return next;
}

function startOfWeek(value) {
  const next = cloneDate(value);
  next.setDate(next.getDate() - next.getDay());
  return next;
}

function endOfWeek(value) {
  return addDays(startOfWeek(value), 6);
}

function startOfMonth(value) {
  return new Date(value.getFullYear(), value.getMonth(), 1);
}

function endOfMonth(value) {
  return new Date(value.getFullYear(), value.getMonth() + 1, 0);
}

function dateKey(value) {
  return `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
}

function buildMonthCells(anchorDate) {
  const firstDay = startOfMonth(anchorDate);
  const lastDay = endOfMonth(anchorDate);
  const cells = [];
  const cursor = addDays(firstDay, -firstDay.getDay());

  while (cells.length < 42) {
    cells.push(new Date(cursor));
    cursor.setDate(cursor.getDate() + 1);
  }

  return { cells, firstDay, lastDay };
}

export default function StudentSchedulesPage() {
  useAuth([2]);

  const [state, setState] = useState({
    loading: true,
    error: '',
    user: null,
    student: null,
    classrooms: [],
    schedules: [],
    materials: [],
  });
  const [view, setView] = useState('month');
  const [anchorDate, setAnchorDate] = useState(() => new Date());
  const [selectedOccurrence, setSelectedOccurrence] = useState(null);

  useEffect(() => {
    let active = true;

    async function load() {
      const base = await loadStudentBaseData();
      if (!active) return;

      if (!base.student) {
        setState((current) => ({ ...current, loading: false, user: base.user, error: 'Student profile not found.' }));
        return;
      }

      const [schedules, materials] = await Promise.all([
        loadStudentSchedules(base.classrooms),
        loadStudentMaterials(base.classrooms),
      ]);

      if (!active) return;

      setState({
        loading: false,
        error: '',
        user: base.user,
        student: base.student,
        classrooms: base.classrooms,
        schedules,
        materials,
      });
    }

    load();
    return () => {
      active = false;
    };
  }, []);

  const subjectColorMap = useMemo(() => {
    const ids = [...new Set(state.schedules.map((schedule) => schedule.subjectId))];
    return new Map(ids.map((id, index) => [id, SUBJECT_COLORS[index % SUBJECT_COLORS.length]]));
  }, [state.schedules]);

  const rangeStart = useMemo(() => {
    if (view === 'month') return startOfMonth(anchorDate);
    if (view === 'week') return startOfWeek(anchorDate);
    return cloneDate(anchorDate);
  }, [anchorDate, view]);

  const rangeEnd = useMemo(() => {
    if (view === 'month') return endOfMonth(anchorDate);
    if (view === 'week') return endOfWeek(anchorDate);
    return cloneDate(anchorDate);
  }, [anchorDate, view]);

  const occurrences = useMemo(
    () => buildScheduleOccurrences(state.schedules, state.classrooms, rangeStart, addDays(rangeEnd, 1)),
    [rangeEnd, rangeStart, state.classrooms, state.schedules],
  );
  const occurrenceMap = useMemo(() => {
    const map = new Map();
    occurrences.forEach((occurrence) => {
      const key = dateKey(occurrence.start);
      const group = map.get(key) ?? [];
      group.push(occurrence);
      map.set(key, group);
    });
    return map;
  }, [occurrences]);
  const materialCountByClassroomId = useMemo(() => {
    return state.materials.reduce((map, material) => {
      map.set(material.classroomId, (map.get(material.classroomId) ?? 0) + 1);
      return map;
    }, new Map());
  }, [state.materials]);

  if (state.loading) {
    return (
      <div className="rounded-[1.8rem] border border-slate-200/70 bg-white/85 p-12 text-center shadow-sm">
        <div className="mx-auto h-8 w-8 animate-spin rounded-full border-2 border-[#526d82] border-t-transparent" />
        <p className="mt-4 text-sm text-slate-500">Loading your schedule...</p>
      </div>
    );
  }

  const monthGrid = buildMonthCells(anchorDate);
  const visibleList = occurrences.slice(0, 12);

  function shiftPeriod(direction) {
    const next = new Date(anchorDate);
    if (view === 'month') next.setMonth(next.getMonth() + direction);
    else if (view === 'week') next.setDate(next.getDate() + 7 * direction);
    else next.setDate(next.getDate() + direction);
    setAnchorDate(next);
  }

  return (
    <StudentPageShell
      title="Schedules"
      description="Switch between month, week, day, and list views to stay on top of your recurring class timetable."
      breadcrumbs={[
        { label: 'Student', href: '/student/dashboard' },
        { label: 'Schedules' },
      ]}
      user={state.user}
      student={state.student}
      actions={
        <>
          <div className="flex flex-wrap gap-2">
            {['month', 'week', 'day', 'list'].map((value) => (
              <button
                key={value}
                type="button"
                onClick={() => setView(value)}
                className={[
                  'rounded-full px-3 py-2 text-sm font-semibold transition',
                  view === value ? 'bg-[#526d82] text-white' : 'bg-white/80 text-slate-600 hover:bg-white',
                ].join(' ')}
              >
                {value[0].toUpperCase() + value.slice(1)}
              </button>
            ))}
          </div>
          <button
            type="button"
            onClick={() =>
              downloadScheduleIcs(
                state.student,
                buildScheduleOccurrences(state.schedules, state.classrooms, new Date(), addDays(new Date(), 60)),
              )
            }
            className="admin-btn-primary"
          >
            <Download className="h-4 w-4" />
            Download iCal
          </button>
        </>
      }
    >
      {state.error ? (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-4 text-sm text-rose-700">{state.error}</div>
      ) : null}

      <StudentSectionCard
        icon={CalendarDays}
        title="Calendar"
        subtitle="Tap an event to see teacher, room, time, and linked materials for that classroom."
        action={
          <div className="flex items-center gap-2">
            <button type="button" onClick={() => shiftPeriod(-1)} className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-slate-600 transition hover:border-slate-300 hover:text-slate-900">
              <ChevronLeft className="h-4 w-4" />
            </button>
            <span className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700">
              {view === 'month'
                ? anchorDate.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
                : `${formatDate(rangeStart, { month: 'short', day: 'numeric' })} - ${formatDate(rangeEnd, { month: 'short', day: 'numeric' })}`}
            </span>
            <button type="button" onClick={() => shiftPeriod(1)} className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-slate-600 transition hover:border-slate-300 hover:text-slate-900">
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        }
      >
        {!state.schedules.length ? (
          <StudentEmptyState
            icon={CalendarDays}
            title="No schedule blocks available"
            description="Once your classrooms have recurring schedules assigned, they will appear in this calendar automatically."
          />
        ) : view === 'month' ? (
          <div className="grid grid-cols-7 gap-3">
            {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) => (
              <div key={day} className="px-2 text-center text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">
                {day}
              </div>
            ))}
            {monthGrid.cells.map((cell) => {
              const items = occurrenceMap.get(dateKey(cell)) ?? [];
              const inMonth = cell.getMonth() === anchorDate.getMonth();
              return (
                <div key={cell.toISOString()} className={`min-h-[9rem] rounded-[1.4rem] border p-3 ${inMonth ? 'border-slate-200 bg-white/80' : 'border-slate-100 bg-slate-50/70'}`}>
                  <div className="flex items-center justify-between gap-2">
                    <span className={`text-sm font-semibold ${inMonth ? 'text-slate-900' : 'text-slate-400'}`}>{cell.getDate()}</span>
                    {items.length ? <StudentStatusBadge label={`${items.length} class${items.length === 1 ? '' : 'es'}`} tone="info" /> : null}
                  </div>
                  <div className="mt-3 space-y-2">
                    {items.slice(0, 3).map((occurrence) => (
                      <button
                        key={`${occurrence.id}-${occurrence.start.toISOString()}`}
                        type="button"
                        onClick={() => setSelectedOccurrence(occurrence)}
                        className="w-full rounded-xl px-2 py-2 text-left text-xs font-medium text-white"
                        style={{ backgroundColor: subjectColorMap.get(occurrence.subjectId) ?? '#526d82' }}
                      >
                        <p className="truncate">{occurrence.subjectName}</p>
                        <p className="mt-1 text-[11px] text-white/80">{formatTimeRange(occurrence.startTime, occurrence.endTime)}</p>
                      </button>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="space-y-3">
            {visibleList.length === 0 ? (
              <StudentEmptyState
                icon={List}
                title="No schedule items in this range"
                description="Try a different calendar window to see upcoming class sessions."
              />
            ) : (
              visibleList.map((occurrence) => (
                <button
                  key={`${occurrence.id}-${occurrence.start.toISOString()}`}
                  type="button"
                  onClick={() => setSelectedOccurrence(occurrence)}
                  className="block w-full rounded-[1.4rem] border border-slate-200/70 bg-white/80 p-4 text-left transition hover:border-slate-300 hover:bg-white"
                >
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p className="text-sm font-semibold text-slate-900">{occurrence.subjectName}</p>
                      <p className="mt-1 text-sm text-slate-500">
                        {formatDate(occurrence.start, { weekday: 'long', month: 'short', day: 'numeric' })} | {formatTimeRange(occurrence.startTime, occurrence.endTime)}
                      </p>
                    </div>
                    <StudentStatusBadge label={occurrence.classroomName} tone="info" />
                  </div>
                  <p className="mt-3 text-sm text-slate-600">{occurrence.teacherName ?? 'Teacher not assigned'} | {occurrence.roomName ?? 'Room not assigned'}</p>
                </button>
              ))
            )}
          </div>
        )}
      </StudentSectionCard>

      {selectedOccurrence ? (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-slate-950/35 p-4 backdrop-blur-sm">
          <div className="w-full max-w-lg rounded-[1.8rem] border border-slate-200 bg-white p-6 shadow-2xl">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Schedule Detail</p>
                <h3 className="mt-2 text-2xl font-semibold text-slate-950">{selectedOccurrence.subjectName}</h3>
                <p className="mt-2 text-sm text-slate-500">{selectedOccurrence.classroomName}</p>
              </div>
              <button type="button" onClick={() => setSelectedOccurrence(null)} className="rounded-xl border border-slate-200 px-3 py-2 text-sm font-medium text-slate-600 transition hover:border-slate-300 hover:text-slate-900">
                Close
              </button>
            </div>

            <div className="mt-6 grid gap-4 sm:grid-cols-2">
              <div className="rounded-2xl border border-slate-200/70 bg-slate-50/80 p-4">
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Time</p>
                <p className="mt-2 text-sm text-slate-700">{formatDate(selectedOccurrence.start, { weekday: 'long', month: 'short', day: 'numeric' })}</p>
                <p className="mt-1 text-sm font-medium text-slate-900">{formatTimeRange(selectedOccurrence.startTime, selectedOccurrence.endTime)}</p>
              </div>
              <div className="rounded-2xl border border-slate-200/70 bg-slate-50/80 p-4">
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Teacher</p>
                <p className="mt-2 text-sm font-medium text-slate-900">{selectedOccurrence.teacherName ?? 'Teacher not assigned'}</p>
                <p className="mt-1 text-sm text-slate-500">{selectedOccurrence.roomName ?? 'Room not assigned'}</p>
              </div>
              <div className="rounded-2xl border border-slate-200/70 bg-slate-50/80 p-4">
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Type</p>
                <p className="mt-2 text-sm font-medium text-slate-900">{selectedOccurrence.typeName ?? 'Regular session'}</p>
              </div>
              <div className="rounded-2xl border border-slate-200/70 bg-slate-50/80 p-4">
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Materials</p>
                <p className="mt-2 text-sm font-medium text-slate-900">{materialCountByClassroomId.get(selectedOccurrence.classroomId) ?? 0} linked resources</p>
              </div>
            </div>

            <div className="mt-6 flex items-center gap-2 rounded-2xl border border-slate-200/70 bg-slate-50/80 px-4 py-3 text-sm text-slate-600">
              <Clock3 className="h-4 w-4" />
              Today&apos;s classes appear at the top of list view, and recurring sessions can be exported to your calendar app with the iCal button.
            </div>
          </div>
        </div>
      ) : null}
    </StudentPageShell>
  );
}
