'use client';

import { useEffect, useState } from 'react';
import { AlertCircle, ArrowRight, History, RefreshCcw } from 'lucide-react';
import { getGradeChanges, getStudents } from '@/lib/api';
import { formatRelativeTime, toArray } from '@/lib/student-portal';

const TAKE_OPTIONS = [50, 100, 200];

const actionStyles = {
  Created: 'bg-emerald-50 text-emerald-700',
  Updated: 'bg-amber-50 text-amber-700',
  Deleted: 'bg-red-50 text-red-700',
};

const selectCls =
  'w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent';

function formatScore(value) {
  return value === null || value === undefined ? '—' : Number(value).toFixed(2).replace(/\.?0+$/, '');
}

// Audit trail (F5): who set, changed or removed a grade, newest first.
export default function GradeChangesPage() {
  const [students, setStudents] = useState([]);
  const [studentId, setStudentId] = useState('');
  const [take, setTake] = useState(50);
  const [state, setState] = useState({ loading: true, error: '', items: [] });
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    getStudents(1, 1000).then((data) => setStudents(toArray(data)));
  }, []);

  useEffect(() => {
    let active = true;
    getGradeChanges({ studentId, take }).then((items) => {
      if (!active) return;
      setState(items === null
        ? { loading: false, error: 'Could not load the grade history.', items: [] }
        : { loading: false, error: '', items: toArray(items) });
    });
    return () => {
      active = false;
    };
  }, [studentId, take, reloadKey]);

  function reload() {
    setState((current) => ({ ...current, loading: true }));
    setReloadKey((key) => key + 1);
  }

  return (
    <div className="admin-page">
      <div className="admin-header">
        <div className="admin-header-main">
          <div className="admin-header-icon">
            <History className="h-5 w-5" />
          </div>
          <div>
            <h1 className="admin-title">Grade history</h1>
            <p className="admin-subtitle">Every grade that was set, changed or removed, and who did it</p>
          </div>
        </div>
        <button type="button" onClick={reload} className="admin-btn-secondary">
          <RefreshCcw className="h-4 w-4" />
          Refresh
        </button>
      </div>

      <div className="admin-card p-5">
        <div className="grid gap-4 sm:grid-cols-[1fr_160px]">
          <div>
            <label htmlFor="student" className="text-xs font-semibold text-slate-700 mb-1.5 block">Student</label>
            <select
              id="student"
              value={studentId}
              onChange={(e) => {
                setStudentId(e.target.value);
                setState((current) => ({ ...current, loading: true }));
              }}
              className={selectCls}
            >
              <option value="">All students</option>
              {students.map((s) => (
                <option key={s.id} value={s.id}>{`${s.firstName} ${s.lastName}`}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="take" className="text-xs font-semibold text-slate-700 mb-1.5 block">Show</label>
            <select
              id="take"
              value={take}
              onChange={(e) => {
                setTake(Number(e.target.value));
                setState((current) => ({ ...current, loading: true }));
              }}
              className={selectCls}
            >
              {TAKE_OPTIONS.map((n) => (
                <option key={n} value={n}>{`Last ${n}`}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {state.error ? (
        <div className="flex items-center gap-3 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          <AlertCircle className="h-5 w-5 shrink-0" />
          {state.error}
        </div>
      ) : null}

      <div className="admin-card overflow-x-auto">
        {state.loading ? (
          <div className="p-12 text-center">
            <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
            <p className="text-slate-500 text-sm">Loading history…</p>
          </div>
        ) : state.items.length === 0 ? (
          <div className="p-12 text-center">
            <History className="w-10 h-10 text-slate-300 mx-auto mb-2" />
            <p className="text-slate-500 text-sm">No grade changes recorded yet.</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-slate-50 border-b border-slate-100">
              <tr>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">When</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Student</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Subject</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Change</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">By</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {state.items.map((c) => (
                <tr key={c.id} className="hover:bg-slate-50/50 transition-colors">
                  <td className="px-5 py-3.5 text-slate-500 whitespace-nowrap" title={new Date(c.changedAt).toLocaleString()}>
                    {formatRelativeTime(c.changedAt)}
                  </td>
                  <td className="px-5 py-3.5 text-slate-900">{c.studentName ?? 'Removed student'}</td>
                  <td className="px-5 py-3.5 text-slate-600">
                    {c.subjectName ?? 'Removed subject'}
                    <span className="block text-xs text-slate-400">{c.semester}</span>
                  </td>
                  <td className="px-5 py-3.5">
                    <span className="flex items-center gap-2">
                      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${actionStyles[c.action] ?? 'bg-slate-100 text-slate-600'}`}>
                        {c.action}
                      </span>
                      <span className="flex items-center gap-1 font-medium text-slate-800">
                        {formatScore(c.oldScore)}
                        <ArrowRight className="h-3.5 w-3.5 text-slate-400" />
                        {formatScore(c.newScore)}
                      </span>
                    </span>
                  </td>
                  <td className="px-5 py-3.5 text-slate-600">
                    {c.changedByName ?? 'Unknown'}
                    {c.changedByRole ? <span className="block text-xs text-slate-400">{c.changedByRole}</span> : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
