from django.urls import path
from . import views

urlpatterns = [
    path('',                     views.NotificationListView.as_view(), name='notification_list'),
    path('unread-count/',         views.UnreadCountView.as_view(),      name='unread_count'),
    path('mark-all-read/',        views.MarkAllReadView.as_view(),      name='mark_all_read'),
    path('<uuid:id>/read/',       views.MarkReadView.as_view(),         name='mark_read'),
]
