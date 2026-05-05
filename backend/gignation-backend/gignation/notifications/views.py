from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from .models import Notification
from .serializers import NotificationSerializer


class NotificationListView(generics.ListAPIView):
    """GET /api/v1/notifications/ — own notifications, newest first."""
    serializer_class   = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(
            user=self.request.user
        ).order_by('-created_at')


class UnreadCountView(APIView):
    """GET /api/v1/notifications/unread-count/ — returns {count: N}."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(
            user=request.user, is_read=False
        ).count()
        return Response({'count': count})


class MarkReadView(APIView):
    """PATCH /api/v1/notifications/<id>/read/ — mark one notification read."""
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, id):
        notif = get_object_or_404(Notification, id=id, user=request.user)
        notif.is_read = True
        notif.save(update_fields=['is_read'])
        return Response(NotificationSerializer(notif).data)


class MarkAllReadView(APIView):
    """PATCH /api/v1/notifications/mark-all-read/ — mark all read."""
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request):
        updated = Notification.objects.filter(
            user=request.user, is_read=False
        ).update(is_read=True)
        return Response({'marked_read': updated})
