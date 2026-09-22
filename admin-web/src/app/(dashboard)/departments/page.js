'use client';

import { useEffect, useState } from 'react';
import { getDepartments, createDepartment, updateDepartment, deleteDepartment, getDepartmentDetail } from '@/lib/api';
import DepartmentForm from '@/components/DepartmentForm';

export default function DepartmentsPage() {
  const [departments, setDepartments] = useState([]);
  const [selectedDepartment, setSelectedDepartment] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  const loadDepartments = async () => {
    try {
      setIsLoading(true);
      const data = await getDepartments();
      if (data) {
        setDepartments(data);
      }
    } catch (err) {
      setError('Failed to load departments');
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadDepartments();
  }, []);

  const handleCreate = (e) => {
    setSelectedDepartment(null);
    setShowForm(true);
    setError('');
  };

  const handleEdit = async (dept) => {
    try {
      const detail = await getDepartmentDetail(dept.id);
      setSelectedDepartment(detail);
      setShowForm(true);
      setError('');
    } catch (err) {
      setError('Failed to load department details');
      console.error(err);
    }
  };

  const handleSubmit = async (formData) => {
    try {
      setIsSubmitting(true);
      setError('');
      
      if (selectedDepartment) {
        const res = await updateDepartment(selectedDepartment.id, formData);
        if (res.ok) {
          setSuccessMessage('Department updated successfully');
          setShowForm(false);
          await loadDepartments();
        } else {
          setError('Failed to update department');
        }
      } else {
        const res = await createDepartment(formData);
        if (res.ok) {
          setSuccessMessage('Department created successfully');
          setShowForm(false);
          await loadDepartments();
        } else {
          setError('Failed to create department');
        }
      }

      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (err) {
      setError('An error occurred');
      console.error(err);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (dept) => {
    if (!confirm(`Are you sure you want to delete "${dept.name}"?`)) return;

    try {
      setIsSubmitting(true);
      const res = await deleteDepartment(dept.id);
      if (res.ok) {
        setSuccessMessage('Department deleted successfully');
        await loadDepartments();
      } else {
        setError('Failed to delete department');
      }
      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (err) {
      setError('An error occurred');
      console.error(err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Departments</h1>
      </div>

      {error && (
        <div className="mb-4 p-4 text-red-700 bg-red-100 rounded-md">
          {error}
        </div>
      )}

      {successMessage && (
        <div className="mb-4 p-4 text-green-700 bg-green-100 rounded-md">
          {successMessage}
        </div>
      )}

      {showForm ? (
        <div className="mb-6 p-6 bg-gray-50 rounded-lg border border-gray-200">
          <h2 className="text-xl font-semibold mb-4">
            {selectedDepartment ? 'Edit Department' : 'Create New Department'}
          </h2>
          <DepartmentForm
            department={selectedDepartment}
            onSubmit={handleSubmit}
            onCancel={() => {
              setShowForm(false);
              setSelectedDepartment(null);
            }}
            isLoading={isSubmitting}
          />
        </div>
      ) : (
        <button
          onClick={handleCreate}
          className="mb-6 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          + New Department
        </button>
      )}

      {isLoading ? (
        <div className="text-center py-8">
          <p className="text-gray-500">Loading departments...</p>
        </div>
      ) : departments.length === 0 ? (
        <div className="text-center py-8">
          <p className="text-gray-500">No departments found</p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full border-collapse">
            <thead>
              <tr className="bg-gray-100 border-b-2 border-gray-300">
                <th className="px-4 py-2 text-left text-sm font-semibold text-gray-700">Name</th>
                <th className="px-4 py-2 text-left text-sm font-semibold text-gray-700">Description</th>
                <th className="px-4 py-2 text-center text-sm font-semibold text-gray-700">Subjects</th>
                <th className="px-4 py-2 text-center text-sm font-semibold text-gray-700">Teachers</th>
                <th className="px-4 py-2 text-center text-sm font-semibold text-gray-700">Status</th>
                <th className="px-4 py-2 text-center text-sm font-semibold text-gray-700">Actions</th>
              </tr>
            </thead>
            <tbody>
              {departments.map(dept => (
                <tr key={dept.id} className="border-b border-gray-200 hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">{dept.name}</td>
                  <td className="px-4 py-3 text-sm text-gray-600 truncate">{dept.description || '—'}</td>
                  <td className="px-4 py-3 text-sm text-center text-gray-600">
                    <span className="inline-block px-2 py-1 bg-blue-100 text-blue-800 rounded">
                      {dept.subjectCount || 0}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-center text-gray-600">
                    <span className="inline-block px-2 py-1 bg-green-100 text-green-800 rounded">
                      {dept.teacherCount || 0}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-center">
                    <span className={`px-2 py-1 rounded text-xs font-semibold ${
                      dept.isActive
                        ? 'bg-green-100 text-green-800'
                        : 'bg-gray-100 text-gray-800'
                    }`}>
                      {dept.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-center space-x-2">
                    <button
                      onClick={() => handleEdit(dept)}
                      className="text-blue-600 hover:text-blue-900 font-medium"
                      disabled={isSubmitting}
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => handleDelete(dept)}
                      className="text-red-600 hover:text-red-900 font-medium"
                      disabled={isSubmitting}
                    >
                      Delete
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
