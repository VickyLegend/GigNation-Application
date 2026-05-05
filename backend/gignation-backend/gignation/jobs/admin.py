from django.contrib import admin
from .models import Job, Application


class ApplicationInline(admin.TabularInline):
    model      = Application
    extra      = 0
    readonly_fields = ['user', 'status', 'created_at']
    fields     = ['user', 'cover_note', 'status', 'created_at']


@admin.register(Job)
class JobAdmin(admin.ModelAdmin):
    list_display   = ['title', 'company', 'user', 'status', 'type',
                      'applicants', 'created_at']
    list_filter    = ['status', 'type', 'category']
    search_fields  = ['title', 'company', 'user__email', 'location']
    readonly_fields = ['applicants', 'created_at', 'updated_at']
    inlines        = [ApplicationInline]


@admin.register(Application)
class ApplicationAdmin(admin.ModelAdmin):
    list_display  = ['user', 'job', 'status', 'created_at']
    list_filter   = ['status']
    search_fields = ['user__email', 'job__title']
    readonly_fields = ['created_at', 'updated_at']
