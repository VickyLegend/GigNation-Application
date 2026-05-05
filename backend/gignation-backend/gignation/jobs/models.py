"""
jobs/models.py
--------------
A Job is posted by a Client.
Freelancers submit Applications against it.
"""
import uuid
from django.db import models
from django.conf import settings
from django.contrib.postgres.fields import ArrayField


class Job(models.Model):

    class Status(models.TextChoices):
        OPEN   = 'open',   'Open'
        CLOSED = 'closed', 'Closed'
        FILLED = 'filled', 'Filled'

    class JobType(models.TextChoices):
        FULL_TIME  = 'full_time',  'Full Time'
        PART_TIME  = 'part_time',  'Part Time'
        CONTRACT   = 'contract',   'Contract'
        FREELANCE  = 'freelance',  'Freelance'
        INTERNSHIP = 'internship', 'Internship'

    # ── Identity ─────────────────────────────────────────────────────────────
    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user         = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                     related_name='jobs_posted',
                                     help_text='The client who posted this job')

    # ── Content ───────────────────────────────────────────────────────────────
    title        = models.CharField(max_length=255)
    company      = models.CharField(max_length=255, blank=True)
    location     = models.CharField(max_length=255, blank=True)
    budget       = models.CharField(max_length=100, blank=True,
                                    help_text='e.g. "$500", "₦200,000", "Negotiable"')
    description  = models.TextField(blank=True)
    requirements = models.TextField(blank=True)
    category     = models.CharField(max_length=100, blank=True)
    type         = models.CharField(max_length=20, choices=JobType.choices,
                                    default=JobType.FREELANCE)
    tags         = ArrayField(models.CharField(max_length=50), blank=True, default=list,
                              help_text='List of skill tags')

    # ── State ─────────────────────────────────────────────────────────────────
    status       = models.CharField(max_length=20, choices=Status.choices,
                                    default=Status.OPEN)
    applicants   = models.PositiveIntegerField(default=0,
                                               help_text='Denormalised count — updated on each application')

    # ── Timestamps ────────────────────────────────────────────────────────────
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'jobs_job'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.title} @ {self.company or "Independent"}'


class Application(models.Model):

    class Status(models.TextChoices):
        PENDING  = 'pending',  'Pending'
        REVIEWED = 'reviewed', 'Reviewed'
        ACCEPTED = 'accepted', 'Accepted'
        REJECTED = 'rejected', 'Rejected'

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    job        = models.ForeignKey(Job, on_delete=models.CASCADE, related_name='applications')
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name='applications',
                                   help_text='The freelancer who applied')
    cover_note = models.TextField(blank=True)
    status     = models.CharField(max_length=20, choices=Status.choices,
                                  default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table  = 'jobs_application'
        ordering  = ['-created_at']
        unique_together = ('job', 'user')   # mirrors Supabase UNIQUE constraint

    def __str__(self):
        return f'{self.user} → {self.job.title} [{self.status}]'
