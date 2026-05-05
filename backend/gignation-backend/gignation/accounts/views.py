from rest_framework import generics, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from .serializers import UserPublicSerializer, UserProfileSerializer, RegisterSerializer

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    """POST /api/v1/auth/register/ — Phase 2 Django-native registration."""
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({
            'user':    UserProfileSerializer(user).data,
            'access':  str(refresh.access_token),
            'refresh': str(refresh),
        }, status=status.HTTP_201_CREATED)


class MyProfileView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/v1/auth/me/ — own profile."""
    serializer_class   = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class UserPublicProfileView(generics.RetrieveAPIView):
    """GET /api/v1/auth/users/<id>/ — public profile of any user."""
    serializer_class   = UserPublicSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset           = User.objects.all()
    lookup_field       = 'id'


class AvatarUploadView(APIView):
    """PATCH /api/v1/auth/me/avatar/ — upload profile photo."""
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request):
        user = request.user
        avatar = request.FILES.get('avatar')
        if not avatar:
            return Response({'detail': 'No file provided.'}, status=400)
        user.avatar = avatar
        user.save(update_fields=['avatar'])
        return Response(UserProfileSerializer(user).data)
