// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Mario Guerriero <mario@elementaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace Scratch.Widgets {

    public class SplitView : Granite.Widgets.CollapsiblePaned {
        public signal void welcome_shown ();
        public signal void welcome_hidden ();
        public signal void document_change (Scratch.Services.Document document);
        public signal void views_changed (uint count);

        private weak MainWindow _window;
        public MainWindow window {
            get {
                return _window;
            }
            construct set {
                _window = value;
            }
        }

        private Code.WelcomeView welcome_view;
        public Scratch.Widgets.DocumentView? current_view = null;

        public GLib.List<Scratch.Widgets.DocumentView> views;
        private GLib.List<Scratch.Widgets.DocumentView> hidden_views;

        public SplitView (MainWindow window) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, window: window);
        }

        construct {
            welcome_view = new Code.WelcomeView (window);

            // Handle Drag-and-drop for files functionality on welcome screen
            Gtk.TargetEntry target = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (welcome_view, Gtk.DestDefaults.ALL, {target}, Gdk.DragAction.COPY);

            welcome_view.drag_data_received.connect ((ctx, x, y, sel, info, time) => {
                var uris = sel.get_uris ();
                if (uris.length > 0) {
                    var view = add_view ();

                    for (var i = 0; i < uris.length; i++) {
                        string filename = uris[i];
                        File file = File.new_for_uri (filename);
                        Scratch.Services.Document doc = new Scratch.Services.Document (window.actions, file);
                        view.open_document (doc);
                    }

                    Gtk.drag_finish (ctx, true, false, time);
                }
            });

            views = new GLib.List<Scratch.Widgets.DocumentView> ();
            hidden_views = new GLib.List<Scratch.Widgets.DocumentView> ();
            show_welcome ();
        }

        public Scratch.Widgets.DocumentView? add_view () {
            if (views.length () >= 2) {
                warning ("Maximum view number was already reached!");
                return null;
            }

            // Hide welcome screen
            if (get_children ().length () > 0) {
                hide_welcome ();
            }

            Scratch.Widgets.DocumentView view;
            if (hidden_views.length () == 0) {
                view = new Scratch.Widgets.DocumentView (window);

                view.empty.connect (() => {
                    remove_view (view); /* Welcome will show if no views left */
                });
            } else {
                view = hidden_views.nth_data (0);
                hidden_views.remove (view);
            }

            view.document_change.connect (on_document_changed);
            view.vexpand = true;

            if (views.length () < 1) {
                pack1 (view, true, true);
            } else {
                pack2 (view, true, true);
            }

            view.show_all ();

            views.append (view);
            view.view_id = views.length ();
            current_view = view;
            debug ("View added successfully");

            // Enbale/Disable useless GtkActions about views
            check_actions ();

            return view;
        }

        public void remove_view (Scratch.Widgets.DocumentView? view = null) {
            // If no specific view is required to be removed, just remove the current one
            if (view == null) {
                view = current_view as Scratch.Widgets.DocumentView;
            }

            if (view == null) {
                warning ("There is no focused view to remove!");
                return;
            }

            foreach (var doc in view.docs) {
                if (!doc.do_close (true)) {
                    view.current_document = doc;
                    return;
                }
            }

            // Swap the position of the second view in the pane when we delete the first one
            if (get_child1 () == view && get_child2 () != null) {
                var right_view = get_child2 () as Scratch.Widgets.DocumentView;
                remove (view);
                remove (right_view);
                pack1 (right_view, true, true);

                view.view_id = 2;
                right_view.view_id = 1;

                view.save_opened_files ();
                right_view.save_opened_files ();
            } else {
                remove (view);
            }

            views.remove (view);
            view.document_change.disconnect (on_document_changed);
            view.visible = false;
            hidden_views.append (view);
            debug ("View removed successfully");

            // Enbale/Disable useless GtkActions about views
            check_actions ();

            // Move the focus on the other view
            if (views.nth_data (0) != null) {
                views.nth_data (0).focus ();
            }

            // Show/Hide welcome screen
            if (this.views.length () == 0) {
                show_welcome ();
            }
        }

        public Scratch.Widgets.DocumentView? get_current_view () {
            views.foreach ((v) => {
                if (v.has_focus) {
                    current_view = v;
                }
            });
            return current_view;
        }

        public bool is_empty () {
            return (views.length () == 0);
        }

        public void show_welcome () {
            pack1 (welcome_view, true, true);
            welcome_view.show_all ();
            welcome_shown ();
            debug ("WelcomeScreen shown successfully");
        }

        public void hide_welcome () {
            if (welcome_view.get_parent () == this) {
                remove (welcome_view);
                welcome_hidden ();
                debug ("WelcomeScreen hidden successfully");
            }
        }

        // Detect the last focused Document throw a signal
        private void on_document_changed (Scratch.Services.Document? document, Scratch.Widgets.DocumentView parent) {
            if (document != null) {
                document_change (document);
            }

            // remember last focused view
            current_view = parent;
        }

        // Check the possibility to add or not a new view
        private void check_actions () {
            ((SimpleAction) window.actions.lookup_action (MainWindow.ACTION_NEW_VIEW)).set_enabled (views.length () < 2);
            ((SimpleAction) window.actions.lookup_action (MainWindow.ACTION_REMOVE_VIEW)).set_enabled (views.length () > 1);
            views_changed (views.length ());
        }
    }
}

