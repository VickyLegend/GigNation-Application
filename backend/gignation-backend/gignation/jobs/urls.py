from django.urls import path
from . import views

urlpatterns = [
    path('',                               views.JobListCreateView.as_view(),    name='job_list'),
    path('mine/',                          views.MyJobsView.as_view(),           name='my_jobs'),
    path('my-applications/',              views.MyApplicationsView.as_view(),   name='my_applications'),
    path('<uuid:id>/',                     views.JobDetailView.as_view(),        name='job_detail'),
    path('<uuid:id>/apply/',               views.ApplyToJobView.as_view(),       name='job_apply'),
    path('<uuid:id>/applications/',        views.JobApplicationsView.as_view(),  name='job_applications'),
    path('applications/<uuid:id>/status/', views.ApplicationStatusView.as_view(), name='application_status'),
]
