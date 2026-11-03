from django.urls import path

from . import views

app_name = "notes"
urlpatterns = [
    path("", views.note_list, name="list"),
    path("notes/new/", views.note_create, name="create"),
    path("notes/<int:pk>/", views.note_detail, name="detail"),
    path("notes/<int:pk>/edit/", views.note_update, name="update"),
    path("notes/<int:pk>/delete/", views.note_delete, name="delete"),
]
