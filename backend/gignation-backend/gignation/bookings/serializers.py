from rest_framework import serializers
from .models import Booking
from accounts.serializers import UserPublicSerializer
from services.serializers import ServiceSerializer


class BookingSerializer(serializers.ModelSerializer):
    client_info  = UserPublicSerializer(source='client',  read_only=True)
    provider_info = UserPublicSerializer(source='provider', read_only=True)
    service_info  = ServiceSerializer(source='service',   read_only=True)

    class Meta:
        model  = Booking
        fields = ['id', 'service', 'service_info', 'client_info', 'provider_info',
                  'status', 'note', 'created_at', 'updated_at']
        read_only_fields = ['id', 'client_info', 'provider_info', 'service_info',
                            'status', 'created_at', 'updated_at']

    def create(self, validated_data):
        user    = self.context['request'].user
        service = validated_data['service']
        validated_data['client']   = user
        validated_data['provider'] = service.provider
        return super().create(validated_data)


class BookingStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Booking
        fields = ['status']
