from django.urls import path
from . import views

urlpatterns = [
    path('',               views.BookServiceView.as_view(),          name='book_service'),
    path('mine/',          views.MyBookingsView.as_view(),           name='my_bookings'),
    path('received/',      views.MyProviderBookingsView.as_view(),   name='received_bookings'),
    path('<uuid:id>/',     views.BookingDetailView.as_view(),        name='booking_detail'),
    path('<uuid:id>/status/', views.UpdateBookingStatusView.as_view(), name='booking_status'),
]
