"""
accounts/models.py
------------------
Custom User model for Gignation.

Role system:
  client     — posts jobs, books services, leaves reviews
  freelancer — offers services, applies to jobs
  admin      — managed via Django admin / is_staff flag

Phase 1: supabase_uid ties this row to the Supabase auth.users record.
Phase 2: supabase_uid can be left null; Django owns auth entirely.
"""
import uuid
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):

    class Role(models.TextChoices):
        CLIENT     = 'client',     'Client'
        FREELANCER = 'freelancer', 'Freelancer'

    # ── Identity ────────────────────────────────────────────────────────────
    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email        = models.EmailField(unique=True)

    # Phase 1 bridge — stores the Supabase auth.users UUID
    supabase_uid = models.CharField(max_length=64, unique=True, null=True, blank=True,
                                    help_text='Supabase auth.users UUID — remove after migration')

    # ── Profile ─────────────────────────────────────────────────────────────
    role         = models.CharField(max_length=20, choices=Role.choices, default=Role.CLIENT)
    full_name    = models.CharField(max_length=255, blank=True)
    phone        = models.CharField(max_length=30, blank=True)
    bio          = models.TextField(blank=True)
    skills       = models.TextField(blank=True, help_text='Comma-separated list of skills')
    avatar       = models.ImageField(upload_to='avatars/%Y/%m/', null=True, blank=True)
    avatar_url   = models.URLField(blank=True,
                                   help_text='External URL (Supabase Storage). '
                                             'Use avatar field when Django owns storage.')
    location     = models.CharField(max_length=255, blank=True)
    is_verified  = models.BooleanField(default=False)

    # ── Rating (denormalised for fast reads) ─────────────────────────────────
    rating       = models.DecimalField(max_digits=3, decimal_places=2, default=5.00)
    review_count = models.PositiveIntegerField(default=0)

    # ── Timestamps ───────────────────────────────────────────────────────────
    updated_at   = models.DateTimeField(auto_now=True)

    USERNAME_FIELD  = 'email'
    REQUIRED_FIELDS = ['username']

    class Meta:
        db_table = 'accounts_user'
        verbose_name = 'User'
        verbose_name_plural = 'Users'

    def __str__(self):
        return f'{self.full_name or self.email} ({self.role})'

    @property
    def is_client(self):
        return self.role == self.Role.CLIENT

    @property
    def is_freelancer(self):
        return self.role == self.Role.FREELANCER

    def get_skills_list(self):
        return [s.strip() for s in self.skills.split(',') if s.strip()]
