"""
jobs/signals.py
---------------
Fire notifications automatically when an Application is created or
its status changes. This replaces the Flutter-side notification inserts.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Application


@receiver(post_save, sender=Application)
def notify_on_application(sender, instance, created, **kwargs):
    # Avoid circular import
    from notifications.models import Notification

    if created:
        # Notify the freelancer who applied
        Notification.objects.create(
            user=instance.user,
            title='Application Submitted',
            body=(f'You applied for "{instance.job.title}" '
                  f'at {instance.job.company or "the company"}.'),
            type=Notification.Type.JOB,
            metadata={'screen': 'job_detail', 'id': str(instance.job.id)},
        )
        # Notify the client who posted the job
        Notification.objects.create(
            user=instance.job.user,
            title='New Application Received',
            body=(f'{instance.user.full_name or instance.user.email} '
                  f'applied for your job "{instance.job.title}".'),
            type=Notification.Type.JOB,
            metadata={'screen': 'job_detail', 'id': str(instance.job.id)},
        )

    else:
        # Status changed — notify the freelancer
        if instance.status in (Application.Status.ACCEPTED, Application.Status.REJECTED):
            verb = 'accepted' if instance.status == Application.Status.ACCEPTED else 'rejected'
            Notification.objects.create(
                user=instance.user,
                title=f'Application {verb.capitalize()}',
                body=f'Your application for "{instance.job.title}" was {verb}.',
                type=Notification.Type.JOB,
                metadata={'screen': 'job_detail', 'id': str(instance.job.id)},
            )
