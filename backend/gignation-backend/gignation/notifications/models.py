"""
notifications/models.py
-----------------------
App-wide notifications. Currently inserted by Django signals
(not by Flutter directly) — keeps notification logic server-side.
"""
import uuid
from django.db import models
from django.conf import settings


class Notification(models.Model):

    class Type(models.TextChoices):
        JOB     = 'job',     'Job'
        BOOKING = 'booking', 'Booking'
        PAYMENT = 'payment', 'Payment'
        REVIEW  = 'review',  'Review'
        PROMO   = 'promo',   'Promo'
        SYSTEM  = 'system',  'System'

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name='notifications')
    title      = models.CharField(max_length=255)
    body       = models.TextField(blank=True)
    type       = models.CharField(max_length=20, choices=Type.choices,
                                  default=Type.SYSTEM)
    is_read    = models.BooleanField(default=False)

    # Optional deep-link: e.g. {"screen": "job_detail", "id": "uuid"}
    metadata   = models.JSONField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications_notification'
        ordering = ['-created_at']

    def __str__(self):
        return f'[{self.type}] {self.title} → {self.user}'
