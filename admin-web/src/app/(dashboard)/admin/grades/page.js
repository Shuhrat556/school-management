'use client';
import { useEffect, useState } from 'react';
import { useAuth } from '@/lib/auth';
import { getGrades, createGrade, deleteGrade, getStudents, getSubjects } from '@/lib/api';
import { BarChart3, Search, AlertCircle, Award, TrendingUp, TrendingDown, Plus, Trash2, X } from 'lucide-react';
import { formatStudentId } from '@/lib/id-formatter';

export default function GradesPage() {
  useAuth();

  const [grades, setGrades] = useState([]);
  const [students, setStudents] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [subjectId, setSubjectId] = useState('');
  const [semester, setSemester] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [gradeForm, setGradeForm] = useState({ studentId: '', subjectId: '', semester: '1', score: '' });

  useEffect(() => {
    async function loadPage() {
      setLoading(true);
      try {
        const [stu, s, data] = await Promise.all([
          getStudents(1, 200),
          getSubjects(),
          getGrades(),
        ]);
        setStudents(stu?.items ?? stu ?? []);
        setSubjects(Array.isArray(s) ? s : s?.items ?? []);
        if (data) {
          setGrades(Array.isArray(data) ? data : data.items ?? []);
        } else {
          setError('Failed to load grades.');
        }
      } catch {
        setError('Failed to load grades.');
      } finally {
        setLoading(false);
      }
    }
    loadPage();
  }, []);

  async function handleSearch(e) {
    e?.preventDefault();
    setLoading(true);
    setError('');
    try {
      const data = await getGrades({
        subjectId: subjectId || undefined,
        semester: semester || undefined,
      });
      if (data) {
        setGrades(Array.isArray(data) ? data : data.items ?? []);
      } else {
        setError('Failed to load grades.');
      }
    } catch {
      setError('Failed to load grades.');
    } finally {
      setLoading(false);
    }
  }

  async function handleCreateGrade(e) {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const res = await createGrade({
        studentId: gradeForm.studentId,
        subjectId: gradeForm.subjectId,
        semester: parseInt(gradeForm.semester),
        score: parseFloat(gradeForm.score),
      });
      if (res?.ok) {
        setShowForm(false);
        setGradeForm({ studentId: '', subjectId: '', semester: '1', score: '' });
        handleSearch();
      } else {
        const data = await res.json().catch(() => ({}));
        setError(data?.message ?? data?.error ?? 'Failed to create grade.');
      }
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id) {
    if (!confirm('Delete this grade record? This cannot be undone.')) return;
    const res = await deleteGrade(id);
    if (res?.ok) {
      setGrades((prev) => prev.filter((g) => g.id !== id));
    } else {
      setError('Failed to delete grade.');
    }
  }

  function gradeLabel(score) {
    if (score === undefined || score === null) return '—';
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  function gradeColor(score) {
    if (score >= 90) return 'bg-emerald-100 text-emerald-700';
    if (score >= 80) return 'bg-blue-100 text-blue-700';
    if (score >= 70) return 'bg-amber-100 text-amber-700';
    if (score >= 60) return 'bg-orange-100 text-orange-700';
    return 'bg-red-100 text-red-700';
  }

  const selectCls = 'admin-input';

  return (
    <div className="admin-page">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="admin-header-icon">
            <BarChart3 className="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Grades</h1>
            <p className="text-sm text-slate-500">View and manage student grades</p>
          </div>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="admin-btn-primary"
        >
          {showForm ? <X className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
          {showForm ? 'Cancel' : 'Add Grade'}
        </button>
      </div>

      {/* Add Grade Form */}
      {showForm && (
        <form onSubmit={handleCreateGrade} className="admin-section">
          <h3 className="font-semibold text-slate-900 mb-4">Record New Grade</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Student *</label>
              <select required value={gradeForm.studentId} onChange={(e) => setGradeForm(f => ({ ...f, studentId: e.target.value }))} className={selectCls}>
                <option value="">Select student...</option>
                {students.map((s) => (
                  <option key={s.id} value={s.id}>{s.firstName} {s.lastName}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Subject *</label>
              <select required value={gradeForm.subjectId} onChange={(e) => setGradeForm(f => ({ ...f, subjectId: e.target.value }))} className={selectCls}>
                <option value="">Select subject...</option>
                {subjects.map((s) => (
                  <option key={s.id} value={s.id}>{s.subjectName}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Semester *</label>
              <select required value={gradeForm.semester} onChange={(e) => setGradeForm(f => ({ ...f, semester: e.target.value }))} className={selectCls}>
                <option value="1">Semester 1</option>
                <option value="2">Semester 2</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5">Score *</label>
              <input type="number" required min="0" max="100" step="0.1" value={gradeForm.score}
                onChange={(e) => setGradeForm(f => ({ ...f, score: e.target.value }))}
                placeholder="0-100"
                className={selectCls} />
            </div>
          </div>
          <div className="mt-4">
            <button type="submit" disabled={saving} className="admin-btn-primary disabled:opacity-50">
              {saving ? (
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <Plus className="w-4 h-4" />
              )}
              {saving ? 'Saving...' : 'Record Grade'}
            </button>
          </div>
        </form>
      )}

      {/* Filters */}
      <form
        onSubmit={handleSearch}
        className="admin-section"
      >
        <div className="flex flex-wrap gap-4 items-end">
          <div className="flex-1 min-w-[180px]">
            <label className="block text-xs font-semibold text-slate-600 mb-1.5">Subject</label>
            <select value={subjectId} onChange={(e) => setSubjectId(e.target.value)} className={selectCls}>
              <option value="">All Subjects</option>
              {subjects.map((s) => (
                <option key={s.id} value={s.id}>{s.subjectName}</option>
              ))}
            </select>
          </div>

          <div className="flex-1 min-w-[160px]">
            <label className="block text-xs font-semibold text-slate-600 mb-1.5">Semester</label>
            <select value={semester} onChange={(e) => setSemester(e.target.value)} className={selectCls}>
              <option value="">All Semesters</option>
              <option value="1">Semester 1</option>
              <option value="2">Semester 2</option>
            </select>
          </div>

          <button
            type="submit"
            className="admin-btn-primary"
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
        <div className="bg-white rounded-2xl border border-slate-100 p-12 text-center">
          <div className="w-8 h-8 border-2 border-violet-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-slate-500 text-sm">Loading grades...</p>
        </div>
      ) : grades.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-100 p-12 text-center">
          <BarChart3 className="w-12 h-12 text-slate-300 mx-auto mb-3" />
          <p className="text-slate-500 text-sm">No grades found. Use filters above and click Search.</p>
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 border-b border-slate-100">
              <tr>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Student</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Subject</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Semester</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Score</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Grade</th>
                <th className="text-left px-5 py-4 font-semibold text-slate-600">Recorded</th>
                <th className="px-5 py-4 w-16"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {grades.map((g) => (
                <tr key={g.id} className="hover:bg-slate-50/50 transition-colors">
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-[#526d82] flex items-center justify-center text-white font-semibold text-xs">
                        {(g.studentName ?? 'S')[0]}
                      </div>
                      <span className="font-medium text-slate-900">{g.studentName ?? formatStudentId(g.studentId)}</span>
                    </div>
                  </td>
                  <td className="px-5 py-4 text-slate-600">{g.subjectName ?? g.subjectId}</td>
                  <td className="px-5 py-4">
                    <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-600">
                      {g.semester ? `Semester ${g.semester}` : '—'}
                    </span>
                  </td>
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-1.5">
                      <span className="font-bold text-slate-900">{g.score !== undefined ? g.score : '—'}</span>
                      {g.score !== undefined && (
                        g.score >= 70 ? <TrendingUp className="w-4 h-4 text-emerald-500" /> : <TrendingDown className="w-4 h-4 text-red-500" />
                      )}
                    </div>
                  </td>
                  <td className="px-5 py-4">
                    <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold ${gradeColor(g.score)}`}>
                      <Award className="w-3.5 h-3.5" />
                      {gradeLabel(g.score)}
                    </span>
                  </td>
                  <td className="px-5 py-4 text-slate-500">
                    {g.createdAt ? new Date(g.createdAt).toLocaleDateString() : '—'}
                  </td>
                  <td className="px-5 py-4">
                    <button
                      onClick={() => handleDelete(g.id)}
                      className="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                      title="Delete"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
