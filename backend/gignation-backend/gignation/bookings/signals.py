"""
bookings/signals.py
-------------------
Fire notifications when a booking is created or its status changes.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Booking


@receiver(post_save, sender=Booking)
def notify_on_booking(sender, instance, created, **kwargs):
    from notifications.models import Notification

    if created:
        Notification.objects.create(
            user=instance.client,
            title='Booking Confirmed',
            body=(
                f'Your booking for "{instance.service.title}" '
                f'with {instance.provider.full_name if instance.provider else "the provider"} '
                f'has been placed.'
            ),
            type=Notification.Type.BOOKING,
            metadata={'screen': 'service_detail', 'id': str(instance.service.id)},
        )
        if instance.provider:
            Notification.objects.create(
                user=instance.provider,
                title='New Booking Request',
                body=(
                    f'{instance.client.full_name or instance.client.email} '
                    f'booked your service "{instance.service.title}".'
                ),
                type=Notification.Type.BOOKING,
                metadata={'screen': 'service_detail', 'id': str(instance.service.id)},
            )
    else:
        status_messages = {
            Booking.Status.CONFIRMED: (
                'Booking Confirmed', 'Your booking has been confirmed by the provider.'),
            Booking.Status.COMPLETED: (
                'Booking Completed', 'Your booking has been marked as complete.'),
            Booking.Status.CANCELLED: (
                'Booking Cancelled', 'Your booking has been cancelled.'),
        }
        if instance.status in status_messages:
            title, body = status_messages[instance.status]
            Notification.objects.create(
                user=instance.client,
                title=title,
                body=body,
                type=Notification.Type.BOOKING,
                metadata={'screen': 'service_detail', 'id': str(instance.service.id)},
            )
