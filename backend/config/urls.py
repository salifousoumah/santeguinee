"""URL configuration for config project (SantéGuinée backend)."""

from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/directory/", include("directory.urls")),
    path("api/accounts/", include("accounts.urls")),
    path("api/scheduling/", include("scheduling.urls")),
    path("api-auth/", include("rest_framework.urls")),
]
