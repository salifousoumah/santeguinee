from rest_framework.routers import DefaultRouter

from django.urls import include, path

from .views import DemandeCodeView, LienProcheViewSet, PatientViewSet, VerificationCodeView

app_name = "accounts"

router = DefaultRouter()
router.register("patients", PatientViewSet, basename="patient")
router.register("liens-proches", LienProcheViewSet, basename="lien-proche")

urlpatterns = [
    path("auth/demande-code/", DemandeCodeView.as_view(), name="demande-code"),
    path("auth/verification-code/", VerificationCodeView.as_view(), name="verification-code"),
    path("", include(router.urls)),
]
