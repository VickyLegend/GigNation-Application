"""
core/permissions.py
-------------------
Reusable DRF permissions used across multiple apps.
"""
from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsOwnerOrReadOnly(BasePermission):
    """
    Object-level permission: only the owner can write; everyone can read.
    The view must call self.get_object() which triggers this check.
    Expects the model to have a field that resolves to the owner user.
    Pass owner_field='user' (default) or override per-view.
    """
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        owner_field = getattr(view, 'owner_field', 'user')
        return getattr(obj, owner_field, None) == request.user


class IsClientUser(BasePermission):
    """Allow access only to users with role='client'."""
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            request.user.role == 'client'
        )


class IsFreelancerUser(BasePermission):
    """Allow access only to users with role='freelancer'."""
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            request.user.role == 'freelancer'
        )


class IsAdminUser(BasePermission):
    """Allow access only to Django superusers or staff."""
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            (request.user.is_staff or request.user.is_superuser)
        )
