'use client';

import { useEffect, useState } from 'react';
import { AlertCircle, CalendarClock, Send } from 'lucide-react';
import { createLeaveRequest, getMyChildren, getMyLeaveRequests } from '@/lib/api';
import { formatRelativeTime, toArray } from '@/lib/student-portal';

const TYPES = [
  { value: 1, label: 'Sick' },
  { value: 2, label: 'Personal' },
  { value: 3, label: 'Other' },
];

const statusStyles = {
  Pending: 'bg-amber-50 text-amber-700',
  Approved: 'bg-emerald-50 text-emerald-700',
  Rejected: 'bg-red-50 text-red-700',
};

const fieldCls = 'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500';

const today = () => new Date().toISOString().slice(0, 10);

function formatDates(r) {
  const fmt = (d) => new Date(`${d}T00:00:00`).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
  return r.startDate === r.endDate ? fmt(r.startDate) : `${fmt(r.startDate)} – ${fmt(r.endDate)}`;
}

// F8: a parent asks the school to excuse a child and follows the decision.
export default function ParentLeaveRequestsPage() {
  const [children, setChildren] = useState([]);
  const [requests, setRequests] = useState({ loading: true, items: [] });
  const [reloadKey, setReloadKey] = useState(0);
  const [form, setForm] = useState({ studentId: '', type: 1, startDate: today(), endDate: '', reason: '' });
  const [message, setMessage] = useState({ error: '', success: '' });
  const [sending, setSending] = useState(false);

  useEffect(() => {
    getMyChildren().then((data) => {
      const list = toArray(data);
      setChildren(list);
      if (list.length === 1) setForm((f) => ({ ...f, studentId: list[0].id }));
    });
  }, []);

  useEffect(() => {
    let active = true;
    getMyLeaveRequests().then((items) => {
      if (active) setRequests({ loading: false, items: toArray(items) });
    });
    return () => {
      active = false;
    };
  }, [reloadKey]);

  async function handleSubmit(e) {
    e.preventDefault();
    setSending(true);
    setMessage({ error: '', success: '' });
    const res = await createLeaveRequest({
      studentId: form.studentId,
      type: Number(form.type),
      startDate: form.startDate,
      endDate: form.endDate || null,
      reason: form.reason.trim(),
    });
    setSending(false);
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setMessage({ error: data.message ?? data.title ?? 'Could not send the request.', success: '' });
      return;
    }
    setMessage({ error: '', success: 'Request sent. You will be notified when the school decides.' });
    setForm((f) => ({ ...f, endDate: '', reason: '' }));
    setReloadKey((key) => key + 1);
  }

  return (
    <div className="space-y-6">
      <div>
        <p className="text-sm font-medium text-slate-500">Family</p>
        <h1 className="text-2xl font-semibold tracking-tight text-slate-950">Leave requests</h1>
      </div>

      <form onSubmit={handleSubmit} className="admin-card space-y-4 p-6">
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor="child" className="mb-1.5 block text-xs font-semibold text-slate-700">Child</label>
            <select id="child" required value={form.studentId} onChange={(e) => setForm((f) => ({ ...f, studentId: e.target.value }))} className={fieldCls}>
              <option value="">Select a child…</option>
              {children.map((c) => (
                <option key={c.id} value={c.id}>{`${c.firstName} ${c.lastName}`}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="type" className="mb-1.5 block text-xs font-semibold text-slate-700">Reason type</label>
            <select id="type" value={form.type} onChange={(e) => setForm((f) => ({ ...f, type: e.target.value }))} className={fieldCls}>
              {TYPES.map((t) => (
                <option key={t.value} value={t.value}>{t.label}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="start" className="mb-1.5 block text-xs font-semibold text-slate-700">From</label>
            <input id="start" type="date" required value={form.startDate} onChange={(e) => setForm((f) => ({ ...f, startDate: e.target.value }))} className={fieldCls} />
          </div>
          <div>
            <label htmlFor="end" className="mb-1.5 block text-xs font-semibold text-slate-700">To (optional)</label>
            <input id="end" type="date" min={form.startDate} value={form.endDate} onChange={(e) => setForm((f) => ({ ...f, endDate: e.target.value }))} className={fieldCls} />
          </div>
        </div>
        <div>
          <label htmlFor="reason" className="mb-1.5 block text-xs font-semibold text-slate-700">Reason</label>
          <textarea id="reason" required maxLength={1000} rows={3} value={form.reason}
            onChange={(e) => setForm((f) => ({ ...f, reason: e.target.value }))}
            placeholder="e.g. Fever, a doctor's note will follow" className={fieldCls} />
        </div>
        {message.error ? (
          <div className="flex items-center gap-2 rounded-lg bg-red-50 p-3 text-sm text-red-700">
            <AlertCircle className="h-4 w-4 shrink-0" />
            {message.error}
          </div>
        ) : null}
        {message.success ? <div className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-700">{message.success}</div> : null}
        <button type="submit" disabled={sending || children.length === 0} className="admin-btn-primary disabled:opacity-50">
          <Send className="h-4 w-4" />
          {sending ? 'Sending…' : 'Send request'}
        </button>
      </form>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Previous requests</h2>
        {requests.loading ? (
          <p className="text-sm text-slate-500">Loading…</p>
        ) : requests.items.length === 0 ? (
          <div className="admin-card flex items-center gap-3 p-6 text-sm text-slate-500">
            <CalendarClock className="h-5 w-5 text-slate-400" />
            No requests yet.
          </div>
        ) : (
          <ul className="space-y-3">
            {requests.items.map((r) => (
              <li key={r.id} className="admin-card p-5">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="font-semibold text-slate-900">{r.studentName}</p>
                    <p className="text-sm text-slate-500">{r.type} · {formatDates(r)} · sent {formatRelativeTime(r.createdAt)}</p>
                  </div>
                  <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${statusStyles[r.status] ?? ''}`}>{r.status}</span>
                </div>
                <p className="mt-3 whitespace-pre-line text-sm text-slate-700">{r.reason}</p>
                {r.reviewNote ? <p className="mt-2 text-xs text-slate-500">School note: “{r.reviewNote}”</p> : null}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
