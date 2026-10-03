'use client';

import { useEffect, useState } from 'react';
import { AlertCircle, CalendarClock, Check, X } from 'lucide-react';
import { useAuth } from '@/lib/auth';
import { decideLeaveRequest, getLeaveRequests } from '@/lib/api';
import { formatRelativeTime, toArray } from '@/lib/student-portal';

const FILTERS = ['Pending', 'Approved', 'Rejected', 'All'];

const statusStyles = {
  Pending: 'bg-amber-50 text-amber-700',
  Approved: 'bg-emerald-50 text-emerald-700',
  Rejected: 'bg-red-50 text-red-700',
};

function formatDates(r) {
  const fmt = (d) => new Date(`${d}T00:00:00`).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
  return r.startDate === r.endDate ? fmt(r.startDate) : `${fmt(r.startDate)} – ${fmt(r.endDate)}`;
}

// F8: requests to excuse a student, filed by the student or a parent; staff decide once.
export default function LeaveRequestsPage() {
  useAuth([4, 1]); // Admins and teachers

  const [filter, setFilter] = useState('Pending');
  const [state, setState] = useState({ loading: true, error: '', items: [] });
  const [reloadKey, setReloadKey] = useState(0);
  const [deciding, setDeciding] = useState(null); // { id, approve }
  const [note, setNote] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let active = true;
    getLeaveRequests({ status: filter === 'All' ? undefined : filter }).then((items) => {
      if (!active) return;
      setState(items === null
        ? { loading: false, error: 'Could not load leave requests.', items: [] }
        : { loading: false, error: '', items: toArray(items) });
    });
    return () => {
      active = false;
    };
  }, [filter, reloadKey]);

  function choose(next) {
    setFilter(next);
    setDeciding(null);
    setState((current) => ({ ...current, loading: true }));
  }

  async function confirmDecision() {
    if (!deciding) return;
    setSaving(true);
    const res = await decideLeaveRequest(deciding.id, deciding.approve, note.trim());
    setSaving(false);
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setState((current) => ({ ...current, error: data.message ?? 'Could not save the decision.' }));
      return;
    }
    setDeciding(null);
    setNote('');
    setState((current) => ({ ...current, loading: true, error: '' }));
    setReloadKey((key) => key + 1);
  }

  return (
    <div className="admin-page">
      <div className="admin-header">
        <div className="admin-header-main">
          <div className="admin-header-icon">
            <CalendarClock className="h-5 w-5" />
          </div>
          <div>
            <h1 className="admin-title">Leave requests</h1>
            <p className="admin-subtitle">Requests from students and parents to excuse an absence</p>
          </div>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {FILTERS.map((f) => (
          <button
            key={f}
            type="button"
            onClick={() => choose(f)}
            className={`rounded-full px-4 py-1.5 text-sm font-medium transition-colors ${filter === f ? 'bg-slate-900 text-white' : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'}`}
          >
            {f}
          </button>
        ))}
      </div>

      {state.error ? (
        <div className="flex items-center gap-3 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          <AlertCircle className="h-5 w-5 shrink-0" />
          {state.error}
        </div>
      ) : null}

      {state.loading ? (
        <div className="flex h-40 items-center justify-center">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-300 border-t-slate-700" />
        </div>
      ) : state.items.length === 0 ? (
        <div className="admin-card p-12 text-center text-sm text-slate-500">
          {filter === 'Pending' ? 'No requests are waiting for a decision.' : 'No requests found.'}
        </div>
      ) : (
        <ul className="space-y-3">
          {state.items.map((r) => (
            <li key={r.id} className="admin-card p-5">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="font-semibold text-slate-900">{r.studentName}</p>
                  <p className="text-sm text-slate-500">
                    {r.type} · {formatDates(r)} · filed {formatRelativeTime(r.createdAt)}
                  </p>
                </div>
                <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${statusStyles[r.status] ?? 'bg-slate-100 text-slate-600'}`}>
                  {r.status}
                </span>
              </div>
              <p className="mt-3 whitespace-pre-line text-sm text-slate-700">{r.reason}</p>
              {r.status !== 'Pending' ? (
                <p className="mt-3 text-xs text-slate-500">
                  {r.status} by {r.reviewedByName ?? 'staff'} {r.reviewedAt ? formatRelativeTime(r.reviewedAt) : ''}
                  {r.reviewNote ? ` — “${r.reviewNote}”` : ''}
                </p>
              ) : deciding?.id === r.id ? (
                <div className="mt-4 space-y-3">
                  <textarea
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                    maxLength={500}
                    rows={2}
                    placeholder="Note for the family (optional)"
                    className="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <div className="flex gap-2">
                    <button type="button" disabled={saving} onClick={confirmDecision}
                      className={`${deciding.approve ? 'admin-btn-primary' : 'admin-btn-secondary text-red-700'} disabled:opacity-50`}>
                      {deciding.approve ? 'Confirm approval' : 'Confirm rejection'}
                    </button>
                    <button type="button" onClick={() => { setDeciding(null); setNote(''); }} className="admin-btn-secondary">
                      Cancel
                    </button>
                  </div>
                </div>
              ) : (
                <div className="mt-4 flex gap-2">
                  <button type="button" onClick={() => setDeciding({ id: r.id, approve: true })} className="admin-btn-primary">
                    <Check className="h-4 w-4" />
                    Approve
                  </button>
                  <button type="button" onClick={() => setDeciding({ id: r.id, approve: false })} className="admin-btn-secondary">
                    <X className="h-4 w-4" />
                    Reject
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
