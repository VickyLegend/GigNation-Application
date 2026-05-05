from rest_framework import serializers
from .models import Service
from accounts.serializers import UserPublicSerializer


class ServiceSerializer(serializers.ModelSerializer):
    provider_info = UserPublicSerializer(source='provider', read_only=True)

    class Meta:
        model  = Service
        fields = ['id', 'provider_info', 'provider_display_name', 'title',
                  'description', 'experience', 'category', 'location',
                  'price', 'per', 'is_available', 'rating', 'review_count',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'provider_info', 'rating', 'review_count',
                            'created_at', 'updated_at']

    def create(self, validated_data):
        user = self.context['request'].user
        validated_data['provider'] = user
        if not validated_data.get('provider_display_name'):
            validated_data['provider_display_name'] = user.full_name or user.email
        return super().create(validated_data)
