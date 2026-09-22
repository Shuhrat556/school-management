'use client';

import { useState, useEffect } from 'react';
import { getDepartments, assignTeacherToDepartment, removeTeacherFromDepartment } from '@/lib/api';

export default function TeacherDepartmentAssignment({ teacher, onUpdate }) {
  const [departments, setDepartments] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isUpdating, setIsUpdating] = useState(false);
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

  const isAssigned = (deptId) => {
    return teacher?.departments?.some(d => d.departmentId === deptId) || false;
  };

  const handleToggle = async (deptId) => {
    try {
      setIsUpdating(true);
      setError('');

      if (isAssigned(deptId)) {
        const res = await removeTeacherFromDepartment(teacher.id, deptId);
        if (res.ok) {
          setSuccessMessage('Department removed successfully');
          onUpdate?.();
        } else {
          setError('Failed to remove department');
        }
      } else {
        const res = await assignTeacherToDepartment(teacher.id, deptId);
        if (res.ok) {
          setSuccessMessage('Department assigned successfully');
          onUpdate?.();
        } else {
          setError('Failed to assign department');
        }
      }

      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (err) {
      setError('An error occurred');
      console.error(err);
    } finally {
      setIsUpdating(false);
    }
  };

  if (isLoading) {
    return <div className="text-gray-500">Loading departments...</div>;
  }

  return (
    <div className="space-y-3">
      {error && (
        <div className="p-3 text-red-700 bg-red-100 rounded-md text-sm">
          {error}
        </div>
      )}

      {successMessage && (
        <div className="p-3 text-green-700 bg-green-100 rounded-md text-sm">
          {successMessage}
        </div>
      )}

      <div className="space-y-2">
        {departments.length === 0 ? (
          <p className="text-gray-500 text-sm">No departments available</p>
        ) : (
          departments.map(dept => (
            <label key={dept.id} className="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
              <input
                type="checkbox"
                checked={isAssigned(dept.id)}
                onChange={() => handleToggle(dept.id)}
                disabled={isUpdating}
                className="w-4 h-4 rounded"
              />
              <span className="text-sm font-medium text-gray-900">{dept.name}</span>
              {dept.description && (
                <span className="text-xs text-gray-500">• {dept.description}</span>
              )}
            </label>
          ))
        )}
      </div>
    </div>
  );
}
