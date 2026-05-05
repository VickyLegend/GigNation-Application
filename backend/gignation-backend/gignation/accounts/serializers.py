from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class UserPublicSerializer(serializers.ModelSerializer):
    """Safe read-only view — shown to other users."""
    skills_list = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = ['id', 'full_name', 'role', 'bio', 'avatar_url',
                  'avatar', 'location', 'rating', 'review_count',
                  'is_verified', 'skills_list']

    def get_skills_list(self, obj):
        return obj.get_skills_list()


class UserProfileSerializer(serializers.ModelSerializer):
    """Full profile — shown only to the owner."""
    skills_list = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = ['id', 'email', 'full_name', 'role', 'phone', 'bio',
                  'skills', 'skills_list', 'avatar', 'avatar_url',
                  'location', 'rating', 'review_count', 'is_verified',
                  'date_joined', 'updated_at']
        read_only_fields = ['id', 'email', 'rating', 'review_count',
                            'is_verified', 'date_joined', 'updated_at']

    def get_skills_list(self, obj):
        return obj.get_skills_list()


class RegisterSerializer(serializers.ModelSerializer):
    password  = serializers.CharField(write_only=True, min_length=6)
    password2 = serializers.CharField(write_only=True, label='Confirm password')

    class Meta:
        model  = User
        fields = ['email', 'full_name', 'role', 'password', 'password2']

    def validate(self, data):
        if data['password'] != data['password2']:
            raise serializers.ValidationError({'password2': 'Passwords do not match.'})
        return data

    def create(self, validated_data):
        validated_data.pop('password2')
        password = validated_data.pop('password')
        email    = validated_data['email'].lower().strip()
        username = email.split('@')[0]
        user = User(email=email, username=username, **validated_data)
        user.set_password(password)
        user.save()
        return user
