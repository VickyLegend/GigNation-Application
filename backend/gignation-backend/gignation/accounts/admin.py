from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display   = ['email', 'full_name', 'role', 'is_verified', 'rating',
                      'review_count', 'date_joined']
    list_filter    = ['role', 'is_verified', 'is_staff', 'is_active']
    search_fields  = ['email', 'full_name', 'phone']
    ordering       = ['-date_joined']
    readonly_fields = ['date_joined', 'updated_at', 'last_login']

    fieldsets = (
        ('Identity',  {'fields': ('email', 'username', 'password', 'supabase_uid')}),
        ('Profile',   {'fields': ('full_name', 'role', 'phone', 'bio', 'skills',
                                  'avatar', 'avatar_url', 'location')}),
        ('Reputation',{'fields': ('is_verified', 'rating', 'review_count')}),
        ('Access',    {'fields': ('is_active', 'is_staff', 'is_superuser',
                                  'groups', 'user_permissions')}),
        ('Timestamps',{'fields': ('date_joined', 'updated_at', 'last_login'),
                       'classes': ('collapse',)}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields':  ('email', 'full_name', 'role', 'password1', 'password2'),
        }),
    )
