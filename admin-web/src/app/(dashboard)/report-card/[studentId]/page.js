'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { AlertCircle, BarChart3, CalendarX2, ClipboardCheck, Download, FileText, GraduationCap, Printer } from 'lucide-react';
import { useAuth } from '@/lib/auth';
import { downloadReportCardCsv, getMyStudent, getReportCard } from '@/lib/api';
import StudentStatCard from '@/components/StudentStatCard';
import { downloadTextFile, getAttendanceTone, getScoreTone } from '@/lib/student-portal';

const toneToStat = { success: 'emerald', warning: 'amber', danger: 'rose' };

const selectCls =
  'w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent';

function formatNumber(value, digits) {
  return value === null || value === undefined ? '—' : Number(value).toFixed(digits);
}

// F4: one student's report card, computed by the server. Students open their own at /report-card/me.
export default function ReportCardPage() {
  useAuth([4, 1, 2, 3]);

  const { studentId: param } = useParams();
  const [studentId, setStudentId] = useState(param === 'me' ? null : param);
  const [semesters, setSemesters] = useState([]);
  const [semester, setSemester] = useState('');
  const [state, setState] = useState({ loading: true, error: '', card: null });
  const [downloading, setDownloading] = useState(false);

  useEffect(() => {
    if (param !== 'me') return;
    getMyStudent().then((me) => {
      if (me) setStudentId(me.id);
      else setState({ loading: false, error: 'Your student profile could not be found.', card: null });
    });
  }, [param]);

  useEffect(() => {
    if (!studentId) return undefined;
    let active = true;
    getReportCard(studentId, { semester }).then((card) => {
      if (!active) return;
      if (card === null) {
        setState({ loading: false, error: 'Could not load the report card.', card: null });
        return;
      }
      setState({ loading: false, error: '', card });
      // The unfiltered card lists every semester the student has grades in.
      if (!semester) setSemesters([...new Set(card.subjects.map((s) => s.semester))]);
    });
    return () => {
      active = false;
    };
  }, [studentId, semester]);

  async function handleDownload() {
    setDownloading(true);
    const file = await downloadReportCardCsv(studentId, { semester });
    setDownloading(false);
    if (file) downloadTextFile(file.fileName, file.blob, 'text/csv;charset=utf-8');
    else setState((current) => ({ ...current, error: 'Could not download the CSV.' }));
  }

  const { card } = state;
  const attendance = card?.attendance;

  return (
    <div className="admin-page">
      <div className="admin-header">
        <div className="admin-header-main">
          <div className="admin-header-icon print:hidden">
            <FileText className="h-5 w-5" />
          </div>
          <div>
            <h1 className="admin-title">Report card</h1>
            <p className="admin-subtitle">
              {card ? `${card.studentName} · ${card.semester ?? 'All semesters'}` : 'Grades and attendance summary'}
            </p>
          </div>
        </div>
        {card ? (
          <div className="flex flex-wrap gap-2 print:hidden">
            <button type="button" onClick={handleDownload} disabled={downloading} className="admin-btn-secondary disabled:opacity-50">
              <Download className="h-4 w-4" />
              {downloading ? 'Preparing…' : 'Download CSV'}
            </button>
            <button type="button" onClick={() => window.print()} className="admin-btn-secondary">
              <Printer className="h-4 w-4" />
              Print / PDF
            </button>
          </div>
        ) : null}
      </div>

      {semesters.length > 1 ? (
        <div className="admin-card p-5 print:hidden">
          <label htmlFor="semester" className="text-xs font-semibold text-slate-700 mb-1.5 block">Semester</label>
          <select
            id="semester"
            value={semester}
            onChange={(e) => {
              setSemester(e.target.value);
              setState((current) => ({ ...current, loading: true }));
            }}
            className={`${selectCls} sm:max-w-xs`}
          >
            <option value="">All semesters</option>
            {semesters.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </div>
      ) : null}

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
      ) : card ? (
        <>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StudentStatCard
              icon={BarChart3}
              label="Average score"
              value={formatNumber(card.averageScore, 1)}
              helper={card.averageScore === null ? 'No grades yet' : `${card.subjects.length} grade${card.subjects.length === 1 ? '' : 's'}`}
              tone={card.averageScore === null ? 'slate' : toneToStat[getScoreTone(card.averageScore)]}
            />
            <StudentStatCard icon={GraduationCap} label="GPA" value={formatNumber(card.gpa, 2)} helper="4.0 scale" tone="blue" />
            <StudentStatCard
              icon={ClipboardCheck}
              label="Attendance"
              value={attendance.rate === null ? '—' : `${formatNumber(attendance.rate, 1)}%`}
              helper={`${attendance.present} present of ${attendance.total} marks`}
              tone={attendance.rate === null ? 'slate' : toneToStat[getAttendanceTone(attendance.rate)]}
            />
            <StudentStatCard
              icon={CalendarX2}
              label="Absences"
              value={attendance.absent}
              helper={`${attendance.late} late`}
              tone={attendance.absent > 0 ? 'amber' : 'slate'}
            />
          </div>

          <div className="admin-card overflow-x-auto">
            {card.subjects.length === 0 ? (
              <p className="p-12 text-center text-sm text-slate-500">No grades recorded for this period.</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="bg-slate-50 border-b border-slate-100">
                  <tr>
                    <th className="text-left px-5 py-4 font-semibold text-slate-600">Subject</th>
                    <th className="text-left px-5 py-4 font-semibold text-slate-600">Semester</th>
                    <th className="text-right px-5 py-4 font-semibold text-slate-600">Score</th>
                    <th className="text-center px-5 py-4 font-semibold text-slate-600">Letter</th>
                    <th className="text-right px-5 py-4 font-semibold text-slate-600">Grade points</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {card.subjects.map((s) => (
                    <tr key={`${s.subjectId}-${s.semester}`}>
                      <td className="px-5 py-3.5 text-slate-900">
                        {s.subjectName}
                        {s.classroomName ? <span className="block text-xs text-slate-400">{s.classroomName}</span> : null}
                      </td>
                      <td className="px-5 py-3.5 text-slate-600">{s.semester}</td>
                      <td className="px-5 py-3.5 text-right font-medium text-slate-900">{Number(s.score).toFixed(1)}</td>
                      <td className="px-5 py-3.5 text-center font-semibold text-slate-700">{s.letter}</td>
                      <td className="px-5 py-3.5 text-right text-slate-600">{Number(s.gradePoints).toFixed(1)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          <p className="text-xs text-slate-400">Generated {new Date(card.generatedAt).toLocaleString()}</p>
        </>
      ) : null}
    </div>
  );
}
