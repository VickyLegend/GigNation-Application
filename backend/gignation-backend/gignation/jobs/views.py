from rest_framework import generics, permissions, status, filters
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.db import IntegrityError
from core.permissions import IsOwnerOrReadOnly
from .models import Job, Application
from .serializers import JobSerializer, ApplicationSerializer, ApplicationStatusSerializer


class JobListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/v1/jobs/          — list all open jobs (searchable, filterable)
    POST /api/v1/jobs/          — post a new job (client only)
    """
    serializer_class   = JobSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends    = [filters.SearchFilter, filters.OrderingFilter]
    search_fields      = ['title', 'company', 'location', 'category', 'tags']
    ordering_fields    = ['created_at', 'applicants']
    ordering           = ['-created_at']

    def get_queryset(self):
        qs = Job.objects.select_related('user').filter(status=Job.Status.OPEN)
        category = self.request.query_params.get('category')
        job_type = self.request.query_params.get('type')
        if category:
            qs = qs.filter(category__iexact=category)
        if job_type:
            qs = qs.filter(type=job_type)
        return qs


class JobDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    /api/v1/jobs/<id>/   — job detail
    PATCH  /api/v1/jobs/<id>/   — update (owner only)
    DELETE /api/v1/jobs/<id>/   — delete (owner only)
    """
    serializer_class   = JobSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrReadOnly]
    queryset           = Job.objects.select_related('user').all()
    lookup_field       = 'id'
    owner_field        = 'user'


class MyJobsView(generics.ListAPIView):
    """GET /api/v1/jobs/mine/ — jobs posted by the logged-in user."""
    serializer_class   = JobSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Job.objects.filter(user=self.request.user).order_by('-created_at')


class ApplyToJobView(APIView):
    """POST /api/v1/jobs/<id>/apply/ — submit an application."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, id):
        job = get_object_or_404(Job, id=id, status=Job.Status.OPEN)
        serializer = ApplicationSerializer(
            data=request.data, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        try:
            application = serializer.save(job=job)
            # Increment denormalised applicant count atomically
            Job.objects.filter(id=job.id).update(
                applicants=job.__class__.objects.filter(id=job.id)
                .values_list('applicants', flat=True)[0] + 1
            )
        except IntegrityError:
            return Response(
                {'detail': 'You have already applied for this job.'},
                status=status.HTTP_409_CONFLICT
            )
        return Response(ApplicationSerializer(application).data,
                        status=status.HTTP_201_CREATED)


class JobApplicationsView(generics.ListAPIView):
    """GET /api/v1/jobs/<id>/applications/ — applications on a job (owner only)."""
    serializer_class   = ApplicationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        job = get_object_or_404(Job, id=self.kwargs['id'], user=self.request.user)
        return Application.objects.filter(job=job).select_related('user')


class ApplicationStatusView(generics.UpdateAPIView):
    """PATCH /api/v1/jobs/applications/<id>/status/ — accept or reject (job owner)."""
    serializer_class   = ApplicationStatusSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Application.objects.filter(job__user=self.request.user)

    def get_object(self):
        return get_object_or_404(self.get_queryset(), id=self.kwargs['id'])


class MyApplicationsView(generics.ListAPIView):
    """GET /api/v1/jobs/my-applications/ — applications by the logged-in user."""
    serializer_class   = ApplicationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Application.objects.filter(
            user=self.request.user
        ).select_related('job', 'user').order_by('-created_at')
