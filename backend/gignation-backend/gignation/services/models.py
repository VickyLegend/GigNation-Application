"""
services/models.py
------------------
A Service is offered by a Freelancer (provider).
Clients create Bookings against it.
"""
import uuid
from django.db import models
from django.conf import settings


class Service(models.Model):

    class Category(models.TextChoices):
        DESIGN      = 'design',      'Design'
        DEVELOPMENT = 'development', 'Development'
        WRITING     = 'writing',     'Writing & Content'
        MARKETING   = 'marketing',   'Marketing'
        VIDEO       = 'video',       'Video & Animation'
        PHOTO       = 'photography', 'Photography'
        CLEANING    = 'cleaning',    'Cleaning'
        REPAIRS     = 'repairs',     'Repairs'
        TRANSPORT   = 'transport',   'Transport'
        SECURITY    = 'security',    'Security'
        OTHER       = 'other',       'Other'

    # ── Identity ──────────────────────────────────────────────────────────────
    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                     related_name='services_offered',
                                     help_text='The freelancer offering this service')
    provider_display_name = models.CharField(max_length=255, blank=True,
                                             help_text='Display name shown on cards '
                                                       '(mirrors Supabase provider text field)')

    # ── Content ───────────────────────────────────────────────────────────────
    title        = models.CharField(max_length=255)
    description  = models.TextField(blank=True)
    experience   = models.TextField(blank=True)
    category     = models.CharField(max_length=30, choices=Category.choices,
                                    default=Category.OTHER)
    location     = models.CharField(max_length=255, blank=True)

    # ── Pricing ───────────────────────────────────────────────────────────────
    price        = models.CharField(max_length=100, blank=True,
                                    help_text='e.g. "$50", "₦25,000"')
    per          = models.CharField(max_length=50, blank=True,
                                    help_text='e.g. "per hour", "per project"')

    # ── State ─────────────────────────────────────────────────────────────────
    is_available = models.BooleanField(default=True)

    # ── Rating (denormalised) ─────────────────────────────────────────────────
    rating       = models.DecimalField(max_digits=3, decimal_places=2, default=5.00)
    review_count = models.PositiveIntegerField(default=0)

    # ── Timestamps ────────────────────────────────────────────────────────────
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'services_service'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.title} by {self.provider}'
