from django.test import TestCase
from django.urls import reverse

from .models import Note


class NoteCrudTests(TestCase):
    def setUp(self):
        self.note = Note.objects.create(title="First note", content="A little content.")

    def test_list_shows_notes(self):
        response = self.client.get(reverse("notes:list"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "First note")

    def test_detail_shows_note(self):
        response = self.client.get(reverse("notes:detail", args=[self.note.pk]))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "A little content.")

    def test_create_saves_note(self):
        response = self.client.post(reverse("notes:create"), {"title": "New note", "content": "New body"})
        self.assertEqual(Note.objects.count(), 2)
        created = Note.objects.get(title="New note")
        self.assertRedirects(response, reverse("notes:detail", args=[created.pk]))

    def test_update_changes_note(self):
        response = self.client.post(reverse("notes:update", args=[self.note.pk]), {"title": "Changed", "content": "Changed body"})
        self.note.refresh_from_db()
        self.assertEqual(self.note.title, "Changed")
        self.assertEqual(self.note.content, "Changed body")
        self.assertRedirects(response, reverse("notes:detail", args=[self.note.pk]))

    def test_delete_requires_confirmation_post(self):
        get_response = self.client.get(reverse("notes:delete", args=[self.note.pk]))
        self.assertEqual(get_response.status_code, 200)
        self.assertEqual(Note.objects.count(), 1)
        response = self.client.post(reverse("notes:delete", args=[self.note.pk]))
        self.assertEqual(Note.objects.count(), 0)
        self.assertRedirects(response, reverse("notes:list"))

    def test_blank_title_and_content_are_rejected(self):
        for field in ("title", "content"):
            data = {"title": "Valid title", "content": "Valid content"}
            data[field] = "   "
            response = self.client.post(reverse("notes:create"), data)
            self.assertEqual(response.status_code, 200)
            self.assertContains(response, "Please enter")
        self.assertEqual(Note.objects.count(), 1)

    def test_missing_note_returns_404(self):
        self.assertEqual(self.client.get(reverse("notes:detail", args=[99999])).status_code, 404)
