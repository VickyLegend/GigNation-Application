"""
bookings/models.py
------------------
A Booking is created by a Client against a Service offered by a Freelancer.
Mirrors the Supabase bookings table exactly, plus adds status history.
"""
import uuid
from django.db import models
from django.conf import settings


class Booking(models.Model):

    class Status(models.TextChoices):
        PENDING   = 'pending',   'Pending'
        CONFIRMED = 'confirmed', 'Confirmed'
        ONGOING   = 'ongoing',   'Ongoing'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'
        DISPUTED  = 'disputed',  'Disputed'

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # mirrors Supabase: client_id and provider_id (not user_id)
    client      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name='bookings_as_client')
    provider    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, blank=True,
                                    related_name='bookings_as_provider')
    service     = models.ForeignKey('services.Service', on_delete=models.CASCADE,
                                    related_name='bookings')

    status      = models.CharField(max_length=20, choices=Status.choices,
                                   default=Status.PENDING)
    note        = models.TextField(blank=True, help_text='Client note to provider')

    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        db_table       = 'bookings_booking'
        ordering       = ['-created_at']
        unique_together = ('service', 'client')   # mirrors Supabase UNIQUE

    def __str__(self):
        return f'Booking #{str(self.id)[:8]} — {self.client} → {self.service}'
