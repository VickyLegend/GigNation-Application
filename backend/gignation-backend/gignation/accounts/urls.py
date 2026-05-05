from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import views

urlpatterns = [
    # Phase 2 Django-native auth
    path('register/',    views.RegisterView.as_view(),          name='register'),
    path('login/',       TokenObtainPairView.as_view(),         name='token_obtain'),
    path('token/refresh/', TokenRefreshView.as_view(),          name='token_refresh'),

    # Profile
    path('me/',          views.MyProfileView.as_view(),         name='my_profile'),
    path('me/avatar/',   views.AvatarUploadView.as_view(),      name='avatar_upload'),
    path('users/<uuid:id>/', views.UserPublicProfileView.as_view(), name='user_public'),
]
