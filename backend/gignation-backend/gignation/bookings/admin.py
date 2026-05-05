from django.contrib import admin
from .models import Booking


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display  = ['id', 'client', 'provider', 'service', 'status', 'created_at']
    list_filter   = ['status']
    search_fields = ['client__email', 'provider__email', 'service__title']
    readonly_fields = ['created_at', 'updated_at']
    list_editable = ['status']
