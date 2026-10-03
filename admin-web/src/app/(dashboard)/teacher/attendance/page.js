'use client';
import { useEffect, useState } from 'react';
import { useAuth } from '@/lib/auth';
import { getAttendance, createAttendance, getClassroom, getClassrooms } from '@/lib/api';
import { ClipboardCheck, Search, AlertCircle, CheckCircle, XCircle, Clock, Calendar, Plus, X } from 'lucide-react';
import { formatStudentId } from '@/lib/id-formatter';

export default function AttendancePage() {
  useAuth([1]);

  const [records, setRecords] = useState([]);
  const [classrooms, setClassrooms] = useState([]);
  // Students of the classroom picked in the form: attendance is only recorded for its roster.
  const [roster, setRoster] = useState([]);
  const [classroomId, setClassroomId] = useState('');
  const [date, setDate] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [attendanceForm, setAttendanceForm] = useState({
    studentId: '', classroomId: '', date: new Date().toISOString().slice(0, 10), status: 'Present', notes: ''
  });

  useEffect(() => {
    async function loadData() {
      const c = await getClassrooms(1, 100);
      setClassrooms(c?.items ?? c ?? []);
    }
    loadData();
  }, []);

  async function handleSearch(e) {
    e?.preventDefault();
    setLoading(true);
    setError('');
    const data = await getAttendance({ classroomId: classroomId || undefined, date: date || undefined });
    if (data) {
      setRecords(Array.isArray(data) ? data : data.items ?? []);
    } else {
      setError('Failed to load attendance records.');
    }
    setLoading(false);
  }

  async function selectFormClassroom(id) {
    setAttendanceForm((f) => ({ ...f, classroomId: id, studentId: '' }));
    setRoster([]);
    if (!id) return;
    const detail = await getClassroom(id);
    setRoster(detail?.students ?? []);
  }

  async function handleCreateAttendance(e) {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const res = await createAttendance(attendanceForm);
      if (res?.ok) {
        setShowForm(false);
        setAttendanceForm({
          studentId: '', classroomId: '', date: new Date().toISOString().slice(0, 10), status: 'Present', notes: ''
        });
        handleSearch();
      } else {
        const data = await res.json().catch(() => ({}));
        setError(data?.details ?? data?.message ?? data?.error ?? 'Failed to record attendance.');
      }
    } finally {
      setSaving(false);
    }
  }

  function statusIcon(status) {
    const s = status?.toLowerCase();
    if (s === 'present') return <CheckCircle className="w-4 h-4" />;
    if (s === 'absent') return <XCircle className="w-4 h-4" />;
    if (s === 'late') return <Clock className="w-4 h-4" />;
    return null;
  }

  function statusBadge(status) {
    const map = {
      present: 'bg-emerald-100 text-emerald-700',
      absent: 'bg-red-100 text-red-700',
      late: 'bg-amber-100 text-amber-700',
    };
    return map[status?.toLowerCase()] ?? 'bg-slate-100 text-slate-600';
  }

  const selectCls = 'w-full border border-slate-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent bg-slate-50';

  return (
    <div className="p-8 max-w-7xl mx-auto relative min-h-full">
      {/* Decorative background blobs */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden -z-10 pointer-events-none">
        <div className="absolute top-[-10%] right-[-5%] w-96 h-96 bg-cyan-400/10 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-[-10%] left-[-5%] w-96 h-96 bg-blue-400/10 rounded-full blur-3xl animate-pulse delay-700" />
      </div>

      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[#526d82] flex items-center justify-center">
            <ClipboardCheck className="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Attendance</h1>
            <p className="text-sm text-slate-500">Track student attendance records</p>
          </div>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="bg-[#526d82] hover:bg-[#27374d] text-white text-sm font-bold px-5 py-3 rounded-2xl shadow-lg shadow-slate-500/20 hover:-translate-y-0.5 transition-all duration-300 flex items-center gap-2"
        >
          {showForm ? <X className="w-5 h-5" /> : <Plus className="w-5 h-5" />}
          {showForm ? 'Cancel' : 'Record Attendance'}
        </button>
      </div>

      {/* Add Attendance Form */}
      {showForm && (
        <form onSubmit={handleCreateAttendance} className="bg-white/80 backdrop-blur-xl rounded-3xl border border-white/60 shadow-2xl shadow-slate-200/50 p-8 mb-8 animate-[fadeIn_0.3s_ease-out]">
          <h3 className="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2"><ClipboardCheck className="text-cyan-500 w-5 h-5"/> Record New Attendance</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Classroom *</label>
              <select required value={attendanceForm.classroomId}
                onChange={(e) => selectFormClassroom(e.target.value)} className={selectCls}>
                <option value="">Select classroom...</option>
                {classrooms.map((c) => (
                  <option key={c.id} value={c.id}>{c.className ?? c.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Student *</label>
              <select required value={attendanceForm.studentId} disabled={!attendanceForm.classroomId}
                onChange={(e) => setAttendanceForm(f => ({ ...f, studentId: e.target.value }))} className={selectCls}>
                <option value="">{attendanceForm.classroomId ? 'Select student...' : 'Select a classroom first'}</option>
                {roster.map((s) => (
                  <option key={s.studentId} value={s.studentId}>{s.firstName} {s.lastName}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Date *</label>
              <input type="date" required value={attendanceForm.date}
                onChange={(e) => setAttendanceForm(f => ({ ...f, date: e.target.value }))} className={selectCls} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Status *</label>
              <select required value={attendanceForm.status}
                onChange={(e) => setAttendanceForm(f => ({ ...f, status: e.target.value }))} className={selectCls}>
                <option value="Present">Present</option>
                <option value="Absent">Absent</option>
                <option value="Late">Late</option>
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Notes</label>
              <input type="text" value={attendanceForm.notes}
                onChange={(e) => setAttendanceForm(f => ({ ...f, notes: e.target.value }))}
                placeholder="Optional notes..." className={selectCls} />
            </div>
          </div>
          <div className="mt-4">
            <button type="submit" disabled={saving}
              className="bg-[#526d82] hover:bg-[#27374d] disabled:opacity-50 text-white text-sm font-bold px-6 py-3 rounded-2xl shadow-lg shadow-slate-500/20 hover:-translate-y-0.5 transition-all duration-300 flex items-center gap-2">
              {saving ? (
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <Plus className="w-5 h-5" />
              )}
              {saving ? 'Saving...' : 'Save Record'}
            </button>
          </div>
        </form>
      )}

      {/* Filters */}
      <form
        onSubmit={handleSearch}
        className="bg-white/80 backdrop-blur-xl rounded-3xl border border-white/60 shadow-xl shadow-slate-200/50 p-6 mb-8"
      >
        <div className="flex flex-wrap gap-4 items-end">
          <div className="flex-1 min-w-[180px]">
            <label className="block text-xs font-semibold text-slate-600 mb-1.5">Classroom</label>
            <select
              value={classroomId}
              onChange={(e) => setClassroomId(e.target.value)}
              className={selectCls}
            >
              <option value="">All Classrooms</option>
              {classrooms.map((c) => (
                <option key={c.id} value={c.id}>{c.className ?? c.name}</option>
              ))}
            </select>
          </div>

          <div className="flex-1 min-w-[160px]">
            <label className="block text-xs font-semibold text-slate-600 mb-1.5">Date</label>
            <div className="relative">
              <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full border border-slate-200 rounded-xl pl-10 pr-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent bg-slate-50"
              />
            </div>
          </div>

          <button
            type="submit"
            className="bg-[#526d82] hover:bg-[#27374d] text-white text-sm font-bold px-8 py-2.5 rounded-xl shadow-lg shadow-slate-500/20 hover:-translate-y-0.5 transition-all duration-300 flex items-center gap-2 h-[42px]"
          >
            <Search className="w-4 h-4" />
            Search
          </button>
        </div>
      </form>

      {error && (
        <div className="flex items-center gap-3 bg-red-50 border border-red-100 text-red-700 text-sm rounded-xl p-4 mb-4">
          <AlertCircle className="w-5 h-5 shrink-0" />
          {error}
          <button onClick={() => setError('')} className="ml-auto text-red-400 hover:text-red-600"><X className="w-4 h-4" /></button>
        </div>
      )}

      {loading ? (
        <div className="bg-white/60 backdrop-blur-md rounded-3xl border border-white/50 p-16 text-center shadow-xl shadow-slate-200/30">
          <div className="w-10 h-10 border-4 border-cyan-500 border-t-transparent rounded-full animate-spin mx-auto mb-4 shadow-sm" />
          <p className="text-slate-600 font-medium tracking-wide">Fetching attendance records...</p>
        </div>
      ) : records.length === 0 ? (
        <div className="bg-white/60 backdrop-blur-md rounded-3xl border border-white/50 p-16 text-center shadow-xl shadow-slate-200/30">
          <div className="w-20 h-20 bg-cyan-50 rounded-full flex items-center justify-center mx-auto mb-4 border border-cyan-100 shadow-inner">
             <ClipboardCheck className="w-10 h-10 text-cyan-400" />
          </div>
          <h3 className="text-lg font-bold text-slate-800 mb-1">No Records Found</h3>
          <p className="text-slate-500 text-sm max-w-sm mx-auto">Use the filters above and click Search to load classroom attendance history.</p>
        </div>
      ) : (
        <div className="bg-white/80 backdrop-blur-xl rounded-3xl border border-white/60 shadow-xl shadow-slate-200/50 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 border-b border-slate-100">
              <tr>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Student</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Classroom</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Date</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Status</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Notes</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {records.map((r) => (
                <tr key={r.id} className="hover:bg-slate-50/50 transition-colors">
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-[#526d82] flex items-center justify-center text-white font-semibold text-xs">
                        {(r.studentName ?? 'S')[0]}
                      </div>
                      <span className="font-medium text-slate-900">{r.studentName ?? formatStudentId(r.studentId)}</span>
                    </div>
                  </td>
                  <td className="px-5 py-4 text-slate-600">{r.classroomName ?? r.classroomId}</td>
                  <td className="px-5 py-4 text-slate-500">
                    {r.date ? new Date(r.date).toLocaleDateString() : '—'}
                  </td>
                  <td className="px-5 py-4">
                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${statusBadge(r.status)}`}>
                      {statusIcon(r.status)}
                      {r.status ?? '—'}
                    </span>
                  </td>
                  <td className="px-5 py-4 text-slate-500 max-w-xs truncate">{r.notes ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

