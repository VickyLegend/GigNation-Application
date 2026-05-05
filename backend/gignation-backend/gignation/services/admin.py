from django.contrib import admin
from .models import Service


@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display  = ['title', 'provider', 'category', 'price', 'per',
                     'is_available', 'rating', 'review_count', 'created_at']
    list_filter   = ['category', 'is_available']
    search_fields = ['title', 'provider__email', 'provider_display_name', 'location']
    readonly_fields = ['rating', 'review_count', 'created_at', 'updated_at']
    list_editable = ['is_available']
