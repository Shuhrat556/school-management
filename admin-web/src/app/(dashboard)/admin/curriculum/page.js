'use client';

import { useEffect, useState } from 'react';
import { getSubjects } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { BookOpen, Filter, Layers3, Search } from 'lucide-react';

function toItems(data) {
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.items)) return data.items;
  return [];
}

function sortNatural(values) {
  return [...values].sort((a, b) => String(a).localeCompare(String(b), undefined, { numeric: true }));
}

function subjectDepartment(subject) {
  return subject.departmentName ?? subject.department ?? '';
}

function subjectYearLevel(subject) {
  if (subject.yearLevel) return subject.yearLevel;
  const match = String(subject.code ?? subject.subjectName ?? '').match(/Y(\d+)\b/i);
  return match ? Number(match[1]) : null;
}

function subjectCategory(subject) {
  if (subject.category) return subject.category;
  const name = String(subject.subjectName ?? '').toLowerCase();
  if (name.includes('business') || name.includes('mathematics')) return 'Foundations';
  if (subjectYearLevel(subject) >= 3) return 'Advanced';
  return 'Core CS';
}

const categoryThemes = {
  Foundations: 'border-sky-200 bg-sky-50/70',
  'Core CS': 'border-emerald-200 bg-emerald-50/70',
  Advanced: 'border-violet-200 bg-violet-50/70',
  Electives: 'border-amber-200 bg-amber-50/70',
};

export default function CurriculumRoadmapPage() {
  useAuth([4]);

  const [subjects, setSubjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [department, setDepartment] = useState('All');
  const [yearLevel, setYearLevel] = useState('All');

  useEffect(() => {
    async function load() {
      const response = await getSubjects();
      setSubjects(toItems(response));
      setLoading(false);
    }

    load();
  }, []);

  const departments = ['All', ...sortNatural([...new Set(subjects.map(subjectDepartment).filter(Boolean))])];
  const years = ['All', ...sortNatural([...new Set(subjects.map(subjectYearLevel).filter(Boolean))]).map(String)];

  const filteredSubjects = subjects.filter((subject) => {
    const matchesSearch =
      !search ||
      [subject.subjectName, subject.code, subject.description, subjectCategory(subject), subjectDepartment(subject)]
        .filter(Boolean)
        .some((value) => value.toLowerCase().includes(search.toLowerCase()));
    const matchesDepartment = department === 'All' || subjectDepartment(subject) === department;
    const matchesYear = yearLevel === 'All' || String(subjectYearLevel(subject)) === yearLevel;
    return matchesSearch && matchesDepartment && matchesYear;
  });

  const grouped = filteredSubjects.reduce((acc, subject) => {
    const year = subjectYearLevel(subject);
    const yearKey = year ? `Year ${year}` : 'Unassigned';
    const categoryKey = subjectCategory(subject);

    if (!acc[yearKey]) acc[yearKey] = {};
    if (!acc[yearKey][categoryKey]) acc[yearKey][categoryKey] = [];
    acc[yearKey][categoryKey].push(subject);
    return acc;
  }, {});

  const overview = {
    totalSubjects: filteredSubjects.length,
    departments: new Set(filteredSubjects.map(subjectDepartment).filter(Boolean)).size,
    categories: new Set(filteredSubjects.map(subjectCategory).filter(Boolean)).size,
    yearLevels: new Set(filteredSubjects.map(subjectYearLevel).filter(Boolean)).size,
  };

  return (
    <div className="space-y-8">
      <section className="rounded-[2rem] border border-slate-200/70 bg-[#f7f9fb] p-6 shadow-[0_20px_80px_-45px_rgba(15,23,42,0.35)] sm:p-8">
        <div className="flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-3xl">
            <div className="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white/80 px-3 py-1 text-xs font-semibold uppercase tracking-[0.22em] text-slate-500">
              <Layers3 className="h-3.5 w-3.5 text-sky-500" />
              Curriculum Planning
            </div>
            <h1 className="mt-5 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
              Academic roadmap by year, department, and category
            </h1>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-600 sm:text-base">
              This view is driven directly by subject metadata from the backend, including year level, category,
              department, code, and description.
            </p>
          </div>

          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {[
              ['Subjects', overview.totalSubjects],
              ['Departments', overview.departments],
              ['Categories', overview.categories],
              ['Year Levels', overview.yearLevels],
            ].map(([label, value]) => (
              <div key={label} className="rounded-3xl border border-white/70 bg-white/80 px-5 py-4 shadow-sm">
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">{label}</p>
                <p className="mt-3 text-3xl font-semibold text-slate-950">{loading ? '--' : value}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="rounded-[1.8rem] border border-slate-200/70 bg-white/90 p-6 shadow-[0_18px_45px_-36px_rgba(15,23,42,0.5)]">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-500">Filter Curriculum</p>
            <h2 className="mt-2 text-xl font-semibold text-slate-950">Find a program slice quickly</h2>
          </div>

          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <label className="flex min-w-[220px] items-center gap-3 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3">
              <Search className="h-4 w-4 text-slate-400" />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search name, code, or description"
                className="w-full bg-transparent text-sm text-slate-700 outline-none placeholder:text-slate-400"
              />
            </label>

            <label className="flex min-w-[180px] items-center gap-3 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3">
              <Filter className="h-4 w-4 text-slate-400" />
              <select
                value={department}
                onChange={(event) => setDepartment(event.target.value)}
                className="w-full bg-transparent text-sm text-slate-700 outline-none"
              >
                {departments.map((item) => (
                  <option key={item} value={item}>
                    {item === 'All' ? 'All departments' : item}
                  </option>
                ))}
              </select>
            </label>

            <label className="flex min-w-[160px] items-center gap-3 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3">
              <BookOpen className="h-4 w-4 text-slate-400" />
              <select
                value={yearLevel}
                onChange={(event) => setYearLevel(event.target.value)}
                className="w-full bg-transparent text-sm text-slate-700 outline-none"
              >
                {years.map((item) => (
                  <option key={item} value={item}>
                    {item === 'All' ? 'All year levels' : `Year ${item}`}
                  </option>
                ))}
              </select>
            </label>
          </div>
        </div>
      </section>

      {loading ? (
        <section className="rounded-[1.8rem] border border-slate-200/70 bg-white/90 p-12 text-center shadow-[0_18px_45px_-36px_rgba(15,23,42,0.5)]">
          <div className="mx-auto h-10 w-10 animate-spin rounded-full border-4 border-sky-500 border-t-transparent" />
          <p className="mt-4 text-sm text-slate-500">Loading curriculum structure...</p>
        </section>
      ) : filteredSubjects.length === 0 ? (
        <section className="rounded-[1.8rem] border border-slate-200/70 bg-white/90 p-12 text-center shadow-[0_18px_45px_-36px_rgba(15,23,42,0.5)]">
          <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-full border border-sky-100 bg-sky-50">
            <BookOpen className="h-9 w-9 text-sky-400" />
          </div>
          <h2 className="mt-5 text-xl font-semibold text-slate-950">No curriculum records match these filters</h2>
          <p className="mt-2 text-sm text-slate-500">Try broadening the search or check that the backend subject data includes year and department metadata.</p>
        </section>
      ) : (
        <section className="space-y-6">
          {Object.keys(grouped)
            .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
            .map((year) => (
              <div
                key={year}
                className="rounded-[1.8rem] border border-slate-200/70 bg-white/90 p-6 shadow-[0_18px_45px_-36px_rgba(15,23,42,0.5)]"
              >
                <div className="flex flex-col gap-2 border-b border-slate-100 pb-5 sm:flex-row sm:items-end sm:justify-between">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-500">Study Block</p>
                    <h2 className="mt-2 text-2xl font-semibold text-slate-950">{year}</h2>
                  </div>
                  <p className="text-sm text-slate-500">
                    {Object.values(grouped[year]).flat().length} subjects grouped into {Object.keys(grouped[year]).length} categories
                  </p>
                </div>

                <div className="mt-6 grid gap-5 lg:grid-cols-2 xl:grid-cols-3">
                  {Object.keys(grouped[year])
                    .sort((a, b) => a.localeCompare(b))
                    .map((category) => (
                      <div
                        key={category}
                        className={`rounded-[1.5rem] border p-5 ${categoryThemes[category] ?? 'border-slate-200 bg-slate-50/80'}`}
                      >
                        <div className="flex items-start justify-between gap-4">
                          <div>
                            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Category</p>
                            <h3 className="mt-2 text-lg font-semibold text-slate-950">{category}</h3>
                          </div>
                          <span className="rounded-full bg-white px-3 py-1 text-xs font-medium text-slate-600 shadow-sm">
                            {grouped[year][category].length}
                          </span>
                        </div>

                        <div className="mt-5 space-y-3">
                          {grouped[year][category]
                            .sort((a, b) => a.subjectName.localeCompare(b.subjectName))
                            .map((subject) => (
                              <article key={subject.id} className="rounded-2xl border border-white/80 bg-white/90 p-4 shadow-sm">
                                <div className="flex flex-wrap items-start justify-between gap-3">
                                  <div className="min-w-0 flex-1">
                                    <h4 className="text-sm font-semibold text-slate-950">{subject.subjectName}</h4>
                                    <p className="mt-1 text-sm text-slate-500">
                                      {subject.description || 'No description provided by the backend yet.'}
                                    </p>
                                  </div>
                                  <span className="rounded-full bg-slate-100 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-600">
                                    {subject.code || 'No code'}
                                  </span>
                                </div>

                                <div className="mt-4 flex flex-wrap gap-2 text-xs text-slate-500">
                                  <span className="rounded-full bg-slate-100 px-3 py-1.5">{subjectDepartment(subject) || 'General department'}</span>
                                  <span className="rounded-full bg-slate-100 px-3 py-1.5">
                                    {subject.teacherNames?.length ? `${subject.teacherNames.length} teacher${subject.teacherNames.length > 1 ? 's' : ''}` : 'No teachers assigned'}
                                  </span>
                                  <span className="rounded-full bg-slate-100 px-3 py-1.5">
                                    {subject.isActive === false ? 'Inactive' : 'Active'}
                                  </span>
                                </div>
                              </article>
                            ))}
                        </div>
                      </div>
                    ))}
                </div>
              </div>
            ))}
        </section>
      )}
    </div>
  );
}
