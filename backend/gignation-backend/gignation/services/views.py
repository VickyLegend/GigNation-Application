from rest_framework import generics, permissions, filters
from core.permissions import IsOwnerOrReadOnly
from .models import Service
from .serializers import ServiceSerializer


class ServiceListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/v1/services/      — list all available services
    POST /api/v1/services/      — offer a new service (freelancer)
    """
    serializer_class   = ServiceSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends    = [filters.SearchFilter, filters.OrderingFilter]
    search_fields      = ['title', 'provider_display_name', 'category', 'location']
    ordering_fields    = ['created_at', 'rating', 'price']
    ordering           = ['-created_at']

    def get_queryset(self):
        qs = Service.objects.select_related('provider')
        category = self.request.query_params.get('category')
        available = self.request.query_params.get('available')
        if category:
            qs = qs.filter(category__iexact=category)
        if available == 'true':
            qs = qs.filter(is_available=True)
        return qs


class ServiceDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    /api/v1/services/<id>/
    PATCH  /api/v1/services/<id>/  — update (provider only)
    DELETE /api/v1/services/<id>/  — delete (provider only)
    """
    serializer_class   = ServiceSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrReadOnly]
    queryset           = Service.objects.select_related('provider').all()
    lookup_field       = 'id'
    owner_field        = 'provider'


class MyServicesView(generics.ListAPIView):
    """GET /api/v1/services/mine/ — services offered by the logged-in user."""
    serializer_class   = ServiceSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Service.objects.filter(provider=self.request.user).order_by('-created_at')
