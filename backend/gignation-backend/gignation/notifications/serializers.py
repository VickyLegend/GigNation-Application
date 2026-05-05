from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Notification
        fields = ['id', 'title', 'body', 'type', 'is_read', 'metadata', 'created_at']
        read_only_fields = ['id', 'title', 'body', 'type', 'metadata', 'created_at']
