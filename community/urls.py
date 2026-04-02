from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import PollViewSet, QuizViewSet

router = DefaultRouter()
router.register(r'polls', PollViewSet, basename='poll')
router.register(r'quizzes', QuizViewSet, basename='quiz')

urlpatterns = [
    path('', include(router.urls)),
]
