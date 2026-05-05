from django.urls import path
from . import views

urlpatterns = [
    path('',             views.ServiceListCreateView.as_view(), name='service_list'),
    path('mine/',        views.MyServicesView.as_view(),        name='my_services'),
    path('<uuid:id>/',   views.ServiceDetailView.as_view(),     name='service_detail'),
]
