from django.contrib import messages
from django.shortcuts import get_object_or_404, redirect, render

from .forms import NoteForm
from .models import Note


def note_list(request):
    return render(request, "notes/note_list.html", {"notes": Note.objects.all()})


def note_detail(request, pk):
    note = get_object_or_404(Note, pk=pk)
    return render(request, "notes/note_detail.html", {"note": note})


def note_create(request):
    if request.method == "POST":
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            messages.success(request, "Your note was created.")
            return redirect("notes:detail", pk=note.pk)
    else:
        form = NoteForm()
    return render(request, "notes/note_form.html", {"form": form, "heading": "Create a note", "button_label": "Save note"})


def note_update(request, pk):
    note = get_object_or_404(Note, pk=pk)
    if request.method == "POST":
        form = NoteForm(request.POST, instance=note)
        if form.is_valid():
            form.save()
            messages.success(request, "Your note was updated.")
            return redirect("notes:detail", pk=note.pk)
    else:
        form = NoteForm(instance=note)
    return render(request, "notes/note_form.html", {"form": form, "heading": "Edit note", "button_label": "Save changes", "note": note})


def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk)
    if request.method == "POST":
        note.delete()
        messages.success(request, "Your note was deleted.")
        return redirect("notes:list")
    return render(request, "notes/note_confirm_delete.html", {"note": note})
