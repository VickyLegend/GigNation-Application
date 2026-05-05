"""
Gignation — Root URL Configuration
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/',          admin.site.urls),

    # API v1
    path('api/v1/auth/',          include('accounts.urls')),
    path('api/v1/jobs/',          include('jobs.urls')),
    path('api/v1/services/',      include('services.urls')),
    path('api/v1/bookings/',      include('bookings.urls')),
    path('api/v1/notifications/', include('notifications.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# Admin branding
admin.site.site_header = 'Gignation Admin'
admin.site.site_title  = 'Gignation'
admin.site.index_title = 'Dashboard'
