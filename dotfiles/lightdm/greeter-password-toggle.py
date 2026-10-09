from pathlib import Path
p = Path('src/lightdm-gtk-greeter.c')
s = p.read_text()
needle = 'static GtkEntry     *username_entry, *password_entry;'
assert s.count(needle) == 1
callbacks = r'''
/* Only the login greeter may reveal a password, and only on explicit click. */
static gboolean criket_secret_prompt = TRUE;
static void
criket_password_icon_update (void)
{
    if (!criket_secret_prompt)
    {
        gtk_entry_set_icon_from_icon_name (password_entry, GTK_ENTRY_ICON_SECONDARY, NULL);
        return;
    }
    gboolean shown = gtk_entry_get_visibility (password_entry);
    gtk_entry_set_icon_from_icon_name (password_entry, GTK_ENTRY_ICON_SECONDARY,
                                     shown ? "view-conceal-symbolic" : "view-reveal-symbolic");
    gtk_entry_set_icon_tooltip_text (password_entry, GTK_ENTRY_ICON_SECONDARY,
                                    shown ? "Скрыть пароль" : "Показать пароль");
}
static void
criket_password_visibility_notify (GObject *object, GParamSpec *spec, gpointer data)
{
    criket_password_icon_update ();
}
static void
criket_password_icon_release (GtkEntry *entry, GtkEntryIconPosition position,
                             GdkEvent *event, gpointer data)
{
    if (position == GTK_ENTRY_ICON_SECONDARY && criket_secret_prompt)
        gtk_entry_set_visibility (entry, !gtk_entry_get_visibility (entry));
}
'''
s = s.replace(needle, needle + '\n' + callbacks)
needle = '    password_entry = GTK_ENTRY (gtk_builder_get_object (builder, "password_entry"));'
assert s.count(needle) == 1
s = s.replace(needle, needle + '''
    gtk_entry_set_visibility (password_entry, FALSE);
    gtk_entry_set_icon_activatable (password_entry, GTK_ENTRY_ICON_SECONDARY, TRUE);
    g_signal_connect (password_entry, "icon-release", G_CALLBACK (criket_password_icon_release), NULL);
    g_signal_connect (password_entry, "notify::visibility", G_CALLBACK (criket_password_visibility_notify), NULL);
    criket_password_icon_update ();''')
needle = '        gtk_entry_set_visibility (password_entry, message->type.prompt != LIGHTDM_PROMPT_TYPE_SECRET);'
assert s.count(needle) == 1
s = s.replace(needle, '''        criket_secret_prompt = message->type.prompt == LIGHTDM_PROMPT_TYPE_SECRET;
''' + needle + '\n        criket_password_icon_update ();')
needle = '    gtk_entry_set_text (password_entry, "");'
# Clear/re-mask on authentication changes. Original prompt code re-enables non-secret prompts.
s = s.replace(needle, needle + '\n    gtk_entry_set_visibility (password_entry, FALSE);')
p.write_text(s)
