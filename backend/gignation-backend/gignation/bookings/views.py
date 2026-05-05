from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.db import IntegrityError
from .models import Booking
from .serializers import BookingSerializer, BookingStatusSerializer


class BookServiceView(APIView):
    """POST /api/v1/bookings/ — client books a service."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = BookingSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        try:
            booking = serializer.save()
        except IntegrityError:
            return Response(
                {'detail': 'You have already booked this service.'},
                status=status.HTTP_409_CONFLICT
            )
        return Response(BookingSerializer(booking).data, status=status.HTTP_201_CREATED)


class MyBookingsView(generics.ListAPIView):
    """GET /api/v1/bookings/mine/ — bookings by the logged-in client."""
    serializer_class   = BookingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Booking.objects.filter(
            client=self.request.user
        ).select_related('client', 'provider', 'service').order_by('-created_at')


class MyProviderBookingsView(generics.ListAPIView):
    """GET /api/v1/bookings/received/ — bookings received by the logged-in provider."""
    serializer_class   = BookingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Booking.objects.filter(
            provider=self.request.user
        ).select_related('client', 'provider', 'service').order_by('-created_at')


class BookingDetailView(generics.RetrieveAPIView):
    """GET /api/v1/bookings/<id>/ — booking detail (client or provider)."""
    serializer_class   = BookingSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field       = 'id'

    def get_queryset(self):
        user = self.request.user
        return Booking.objects.filter(
            client=user
        ) | Booking.objects.filter(provider=user)


class UpdateBookingStatusView(generics.UpdateAPIView):
    """PATCH /api/v1/bookings/<id>/status/ — provider updates booking status."""
    serializer_class   = BookingStatusSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field       = 'id'

    def get_queryset(self):
        return Booking.objects.filter(provider=self.request.user)
