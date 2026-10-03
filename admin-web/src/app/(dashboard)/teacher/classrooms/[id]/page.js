'use client';
import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/lib/auth';
import { getClassroom, getStudents, enrollStudent, unenrollStudent } from '@/lib/api';
import { School, ArrowLeft, AlertCircle, Users, Plus, X, Trash2, Search, TriangleAlert } from 'lucide-react';

export default function TeacherClassroomDetailPage() {
  useAuth([1]);

  const { id } = useParams();
  const [classroom, setClassroom] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [allStudents, setAllStudents] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [selectedStudentId, setSelectedStudentId] = useState('');
  const [saving, setSaving] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [studentToDelete, setStudentToDelete] = useState(null);
  const [isDeleting, setIsDeleting] = useState(false);
  
  const filteredStudents = allStudents.filter(s => 
    (s.firstName + ' ' + s.lastName + ' ' + (s.email || '')).toLowerCase().includes(searchTerm.toLowerCase())
  );

  const loadData = async () => {
    try {
      const [cls, stuRes] = await Promise.all([
        getClassroom(id),
        getStudents(1, 200)
      ]);
      if (cls) setClassroom(cls);
      else setError('Classroom not found.');
      setAllStudents(stuRes?.items ?? stuRes ?? []);
    } catch (err) {
      setError('Failed to load classroom details.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [id]);

  async function handleEnroll(e) {
    if (e) e.preventDefault();
    if (!selectedStudentId) return;
    setSaving(true);
    try {
      const res = await enrollStudent(id, selectedStudentId);
      if (res?.ok) {
        setShowForm(false);
        setSelectedStudentId('');
        await loadData();
      } else {
        const data = await res.json().catch(() => ({}));
        alert(data?.message ?? data?.error ?? 'Failed to enroll student. They may already be enrolled.');
      }
    } finally {
      setSaving(false);
    }
  }

  async function handleUnenroll() {
    if (!studentToDelete) return;
    setIsDeleting(true);
    try {
      const res = await unenrollStudent(id, studentToDelete.studentId ?? studentToDelete.id);
      if (res?.ok) {
        await loadData();
        setStudentToDelete(null);
      } else {
        alert('Failed to remove student.');
      }
    } catch (err) {
      alert('Error removing student.');
    } finally {
      setIsDeleting(false);
    }
  }

  if (loading) {
    return (
      <div className="max-w-3xl">
        <div className="bg-white rounded-2xl border border-slate-100 p-12 text-center">
          <div className="w-8 h-8 border-2 border-purple-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-slate-500 text-sm">Loading classroom details...</p>
        </div>
      </div>
    );
  }

  if (error || !classroom) {
    return (
      <div className="max-w-3xl">
        <div className="flex items-center gap-3 bg-red-50 border border-red-100 text-red-700 text-sm rounded-xl p-4">
          <AlertCircle className="w-5 h-5 shrink-0" />
          {error || 'Classroom not found.'}
        </div>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-5xl mx-auto relative min-h-full">
      {/* Decorative background blobs */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden -z-10 pointer-events-none" />

      {/* Header */}
      <div className="flex items-center gap-4 mb-8">
        <Link href="/teacher/classrooms" className="p-3 bg-white/50 backdrop-blur-md shadow-sm border border-white/60 hover:shadow-md hover:bg-white/80 rounded-2xl transition-all hover:-translate-y-0.5">
          <ArrowLeft className="w-5 h-5" />
        </Link>
        <div className="w-14 h-14 rounded-2xl bg-[#526d82] flex items-center justify-center shadow-xl shadow-slate-500/20">
          <School className="w-7 h-7 text-white" />
        </div>
        <div>
          <h1 className="text-3xl font-extrabold text-[#27374d]">{classroom.className ?? classroom.name}</h1>
          <p className="text-sm font-medium text-purple-600">
            {classroom.grade ? `Grade ${classroom.grade}` : 'No Grade specified'}
          </p>
        </div>
      </div>

      {/* Overview Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 mb-8">
        <div className="bg-white/80 backdrop-blur-xl p-6 rounded-3xl border border-white/60 shadow-xl shadow-slate-200/50 flex items-center gap-5 hover:shadow-2xl hover:-translate-y-1 transition-all duration-300">
          <div className="p-4 bg-[#526d82] rounded-2xl shadow-lg shadow-slate-500/20">
            <Users className="w-7 h-7 text-white" />
          </div>
          <div>
            <p className="text-sm text-slate-500 font-medium">Total Students</p>
            <p className="text-2xl font-bold text-slate-900">{(classroom.students ?? []).length}</p>
          </div>
        </div>
      </div>

      {/* Enrolled students list */}
      <section className="bg-white/80 backdrop-blur-xl rounded-3xl border border-white/60 shadow-xl shadow-slate-200/50 overflow-hidden">
        <div className="px-8 py-6 border-b border-slate-100/50 bg-slate-50/30 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-indigo-100 text-indigo-600 rounded-lg">
              <Users className="w-5 h-5" />
            </div>
            <h2 className="text-lg font-bold text-slate-800">
              Student Roster
            </h2>
          </div>
          <button
            onClick={() => setShowForm(!showForm)}
            className="bg-[#526d82] hover:bg-[#27374d] text-white text-sm font-bold px-4 py-2 rounded-xl shadow-lg shadow-slate-500/20 hover:-translate-y-0.5 transition-all duration-300 flex items-center gap-2"
          >
            {showForm ? <X className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
            {showForm ? 'Cancel' : 'Add Student'}
          </button>
        </div>

        {/* Add Student Form */}
        {showForm && (
          <form onSubmit={handleEnroll} className="p-6 bg-slate-50/50 border-b border-slate-100/50 animate-[fadeIn_0.3s_ease-out]">
             <div className="max-w-2xl">
               <label className="block text-xs font-semibold text-slate-600 mb-2">Select Student to Enroll</label>
               <div className="relative mb-3">
                 <Search className="w-4 h-4 absolute left-3 top-3 text-slate-400" />
                 <input 
                   type="text" 
                   placeholder="Search by name or email..." 
                   value={searchTerm}
                   onChange={(e) => setSearchTerm(e.target.value)}
                   className="w-full pl-9 pr-4 py-2 bg-white/80 backdrop-blur-md border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 shadow-sm transition-all"
                 />
               </div>
               <div className="max-h-56 overflow-y-auto border border-slate-200 rounded-xl bg-white shadow-inner mb-4">
                 {filteredStudents.length === 0 ? (
                   <div className="p-6 text-center text-sm text-slate-500">No students match your search.</div>
                 ) : (
                   filteredStudents.map(s => (
                     <div 
                       key={s.id} 
                       onClick={() => setSelectedStudentId(s.id)} 
                       className={`p-3 border-b border-slate-50 cursor-pointer flex items-center justify-between transition-colors ${selectedStudentId === s.id ? 'bg-purple-50 border-l-[3px] border-l-purple-500 shadow-inner' : 'hover:bg-slate-50 border-l-[3px] border-l-transparent'}`}
                     >
                       <div>
                         <div className={`font-semibold text-sm ${selectedStudentId === s.id ? 'text-purple-700' : 'text-slate-800'}`}>{s.firstName} {s.lastName}</div>
                         <div className="text-xs text-slate-500">{s.email || 'No email'}</div>
                       </div>
                       {selectedStudentId === s.id && <div className="w-2.5 h-2.5 rounded-full bg-purple-500 shadow-sm shadow-purple-500/50"></div>}
                     </div>
                   ))
                 )}
               </div>
               <button type="submit" disabled={saving || !selectedStudentId}
                 className="bg-[#526d82] hover:bg-[#27374d] disabled:opacity-50 text-white text-sm font-bold px-6 py-2.5 rounded-xl shadow-lg shadow-slate-500/20 hover:-translate-y-0.5 transition-all duration-300 flex items-center gap-2 h-[42px] justify-center w-full sm:w-auto">
                 {saving ? <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> : <Plus className="w-4 h-4" />}
                 {saving ? 'Adding...' : 'Enroll Selected Student'}
               </button>
             </div>
          </form>
        )}

        {(classroom.students ?? []).length === 0 ? (
           <div className="text-center py-12">
             <Users className="w-12 h-12 text-slate-200 mx-auto mb-3" />
             <p className="text-slate-500 text-sm">No students currently enrolled in this class.</p>
           </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-slate-50 border-b border-slate-100">
               <tr>
                 <th className="text-left px-6 py-3 font-semibold text-slate-600">Student Name</th>
                 <th className="text-left px-6 py-3 font-semibold text-slate-600">Email</th>
                 <th className="text-left px-6 py-3 font-semibold text-slate-600">Phone</th>
                 <th className="text-left px-6 py-3 font-semibold text-slate-600">Gender</th>
                 <th className="text-left px-6 py-3 font-semibold text-slate-600">Date of Birth</th>
                 <th className="px-6 py-3 w-16"></th>
               </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
               {(classroom.students ?? []).map((s, i) => (
                 <tr key={s.id ?? i} className="hover:bg-slate-50/50 transition-colors">
                   <td className="px-6 py-4">
                     <div className="flex items-center gap-3">
                       <div className="w-9 h-9 rounded-full bg-[#526d82] flex items-center justify-center text-white font-semibold text-sm shadow-sm">
                         {s.firstName?.[0]}{s.lastName?.[0]}
                       </div>
                       <Link href={`/report-card/${s.studentId ?? s.id}`} className="font-medium text-slate-900 hover:text-[#526d82] hover:underline" title="Open report card">
                         {s.firstName} {s.lastName}
                       </Link>
                     </div>
                   </td>
                   <td className="px-6 py-4 text-slate-500">
                     {s.email ?? '—'}
                   </td>
                   <td className="px-6 py-4 text-slate-500">
                     {s.phoneNumber ?? s.phone ?? '—'}
                   </td>
                   <td className="px-6 py-4 text-slate-500 capitalize">
                     {s.gender ?? '—'}
                   </td>
                   <td className="px-6 py-4 text-slate-500">
                     {s.dateOfBirth || s.dob ? new Date(s.dateOfBirth || s.dob).toLocaleDateString() : '—'}
                   </td>
                   <td className="px-6 py-4">
                     <button
                       onClick={() => setStudentToDelete(s)}
                       className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                       title="Remove from class"
                     >
                       <Trash2 className="w-4 h-4" />
                     </button>
                   </td>
                 </tr>
               ))}
            </tbody>
          </table>
        )}
      </section>

      {/* Delete Confirmation Modal */}
      {studentToDelete && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
          {/* Backdrop */}
          <div className="absolute inset-0 bg-slate-900/40 backdrop-blur-sm animate-[fadeIn_0.2s_ease-out]" onClick={() => !isDeleting && setStudentToDelete(null)}></div>
          
          {/* Modal */}
          <div className="relative bg-white/90 backdrop-blur-xl border border-white/60 shadow-2xl rounded-3xl w-full max-w-md p-6 animate-[slideUp_0.3s_ease-out]">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center shrink-0 shadow-inner">
                <TriangleAlert className="w-6 h-6 text-red-600" />
              </div>
              <div>
                <h3 className="text-xl font-bold text-slate-900">Remove Student</h3>
                <p className="text-sm text-slate-500 mt-1">
                  Are you sure you want to remove <span className="font-semibold text-slate-700">{studentToDelete.firstName} {studentToDelete.lastName}</span> from this class?
                </p>
              </div>
            </div>
            
            <div className="flex gap-3 justify-end mt-8">
              <button 
                onClick={() => setStudentToDelete(null)}
                disabled={isDeleting}
                className="px-5 py-2.5 rounded-xl text-sm font-semibold text-slate-600 hover:bg-slate-100 transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button 
                onClick={handleUnenroll}
                disabled={isDeleting}
                className="bg-[#526d82] hover:bg-[#27374d] disabled:opacity-50 text-white text-sm font-bold px-6 py-2.5 rounded-xl shadow-lg shadow-slate-500/20 hover:-translate-y-0.5 transition-all duration-300 flex items-center gap-2"
              >
                {isDeleting ? <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> : <Trash2 className="w-4 h-4" />}
                {isDeleting ? 'Removing...' : 'Remove'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
