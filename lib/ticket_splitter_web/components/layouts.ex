defmodule TicketSplitterWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TicketSplitterWeb, :html

  alias TicketSplitterWeb.Components.SEOMeta

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :locale, :string, default: "en", doc: "current locale"
  attr :current_path, :string, default: "/", doc: "current request path"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen-dynamic bg-base-300">
      <header class="bg-base-300 border-b border-base-content/20 flex-none">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-18 sm:h-22">
            <a href={"/#{@locale}/"} class="flex items-center gap-1.5 sm:gap-2 min-w-0">
              <img
                src={~p"/images/logo.svg"}
                alt=""
                class="h-6 sm:h-7 w-auto flex-shrink-0"
                loading="eager"
                width="24"
                height="24"
              />
              <span class="text-lg sm:text-xl font-bold text-base-content whitespace-nowrap">
                TicketSplitter
              </span>
            </a>
            <div class="flex items-center gap-2">
              <.language_selector locale={@locale} current_path={@current_path} />
              <.theme_toggle />
              <.user_settings_button />
            </div>
          </div>
        </div>
      </header>

      <main class="flex-1 flex flex-col bg-base-100 relative">
        {render_slot(@inner_block)}
      </main>

      <footer class="flex-none bg-base-300 border-t border-base-content/20 py-2">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-center text-xs text-base-content/60">
            @kukapu - v{app_version()}
          </p>
        </div>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center gap-0.5 sm:gap-1 border sm:border-2 border-base-300 bg-base-300 rounded-full p-0.5 sm:p-1 h-8 sm:h-auto">
      <div class="absolute w-1/2 h-7 sm:h-full rounded-full border-1 border-base-200 bg-base-100 left-0 [[data-theme=dark]_&]:left-1/2 transition-[left] shadow-md top-0.5 sm:top-0" />

      <button
        class="flex p-1 sm:p-3 cursor-pointer w-1/2 h-7 sm:h-auto items-center justify-center hover:scale-110 transition-transform rounded-full z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-5 sm:size-7 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-1 sm:p-3 cursor-pointer w-1/2 h-7 sm:h-auto items-center justify-center hover:scale-110 transition-transform rounded-full z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-5 sm:size-7 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  @doc """
  User settings button that opens a modal to edit the username stored in localStorage.
  Includes the modal markup and JavaScript for localStorage management.
  Shows name first with edit button, then input when editing.
  Refreshes page on save if name changed.
  """
  def user_settings_button(assigns) do
    ~H"""
    <div id="user-settings-container">
      <button
        id="user-settings-btn"
        class="flex items-center justify-center p-1 sm:p-3 aspect-square bg-base-200 hover:bg-base-300 border sm:border-2 border-base-300 rounded-full transition-all hover:scale-110 cursor-pointer shadow-sm"
        onclick="window.openUserSettingsModal()"
        title={gettext("User settings")}
      >
        <.icon
          name="hero-user"
          class="size-5 sm:size-7 text-base-content opacity-75 hover:opacity-100"
        />
      </button>

      <%!-- User Settings Modal --%>
      <div
        id="user-settings-modal"
        class="fixed inset-0 z-50 hidden items-center justify-center bg-black/60 backdrop-blur-md transition-opacity p-4"
        onclick="if(event.target === this) { event.preventDefault(); window.closeUserSettingsModal(); }"
      >
        <div id="user-settings-modal-content" class="bg-base-300 border border-base-300 rounded-2xl shadow-2xl w-full max-w-sm p-4 sm:p-5 transform transition-all animate-fade-in text-left">
          <div class="flex items-center justify-between mb-3">
            <h3 id="user-settings-modal-title" class="text-base sm:text-lg font-bold text-base-content flex items-center gap-2">
              <span id="user-settings-modal-icon" class="text-primary">
                <.icon name="hero-user-circle" class="size-5" />
              </span>
              <span id="user-settings-modal-title-text">{gettext("Your name")}</span>
            </h3>
            <button
              onclick="window.closeUserSettingsModal()"
              class="btn btn-ghost btn-sm btn-circle"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <%!-- View Mode --%>
          <div id="user-name-view" class="space-y-3">
            <div class="flex items-center gap-3 p-2.5 bg-base-200 rounded-xl">
              <div class="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center flex-shrink-0">
                <.icon name="hero-user" class="size-4 text-primary" />
              </div>
              <span
                id="user-name-display"
                class="text-base-content font-medium text-sm sm:text-base truncate flex-1"
              >
                -
              </span>
            </div>
            <button
              onclick="window.startEditingUserName()"
              class="w-full flex items-center justify-center gap-2 p-3 bg-primary/10 hover:bg-primary/20 border-2 border-dashed border-primary/40 hover:border-primary rounded-xl transition-colors"
            >
              <.icon name="hero-pencil" class="size-4 text-primary" />
              <span class="font-medium text-sm text-primary">{gettext("Edit")}</span>
            </button>
          </div>

          <%!-- Edit Mode (hidden by default) --%>
          <div id="user-name-edit" class="space-y-3 hidden">
            <input
              type="text"
              id="user-name-input"
              class="w-full bg-base-200 border border-base-100/20 focus:border-primary focus:ring-4 focus:ring-primary/20 rounded-xl px-3.5 py-2.5 text-sm sm:text-base text-base-content transition-all outline-none"
              placeholder={gettext("Enter your name")}
              maxlength="50"
              style="font-size: 16px"
            />
            <div class="grid grid-cols-2 gap-3">
              <button
                onclick="window.cancelEditingUserName()"
                class="flex items-center justify-center gap-2 p-3 bg-base-200 hover:bg-base-200/80 rounded-xl transition-colors"
              >
                <span class="font-medium text-sm text-base-content">{gettext("Cancel")}</span>
              </button>
              <button
                onclick="window.saveUserSettings()"
                class="flex items-center justify-center gap-2 p-3 bg-primary hover:bg-primary/90 rounded-xl transition-colors"
              >
                <.icon name="hero-check" class="size-4 text-primary-content" />
                <span class="font-medium text-sm text-primary-content">{gettext("Save")}</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <script>
        // Store original name to detect changes
        window._originalUserName = '';
        window._openInEditMode = false;

        // User Settings Modal Functions
        window.openUserSettingsModal = function(editMode) {
          const modal = document.getElementById('user-settings-modal');
          const viewMode = document.getElementById('user-name-view');
          const editModeEl = document.getElementById('user-name-edit');
          const display = document.getElementById('user-name-display');
          const input = document.getElementById('user-name-input');

          // Check if we're in acting_as mode
          const actingAs = window._actingAsParticipant;
          let currentName;

          if (actingAs) {
            // Editing acting_as participant
            currentName = actingAs.name;
          } else {
            // Editing own name from localStorage
            currentName = localStorage.getItem('participant_name') || '';
          }

          window._originalUserName = currentName;

          // Update display
          display.textContent = currentName || '-';

          // Update modal styling based on acting_as mode
          const modalContent = document.getElementById('user-settings-modal-content');
          const modalIcon = document.getElementById('user-settings-modal-icon');
          const modalTitleText = document.getElementById('user-settings-modal-title-text');

          if (actingAs) {
            // Acting as mode: orange border and "Editing: Name"
            modalContent.classList.remove('border-base-300');
            modalContent.classList.add('border-warning', 'border-2');
            modalIcon.classList.remove('text-primary');
            modalIcon.classList.add('text-warning');
            modalTitleText.textContent = "<%= gettext("Editing participant") %>";
          } else {
            // Normal mode
            modalContent.classList.remove('border-warning', 'border-2');
            modalContent.classList.add('border-base-300');
            modalIcon.classList.remove('text-warning');
            modalIcon.classList.add('text-primary');
            modalTitleText.textContent = "<%= gettext("Your name") %>";
          }

          // Show modal and block scroll
          modal.classList.remove('hidden');
          modal.classList.add('flex');
          document.body.classList.add('overflow-hidden');

          // Ensure scroll lock is applied even if another modal animation removes it
          // This fixes a race condition when coming from the participant selector modal
          window._ensureScrollLockInterval = setInterval(() => {
            if (modal.classList.contains('flex') && !modal.classList.contains('hidden')) {
              document.body.classList.add('overflow-hidden');
            } else {
              clearInterval(window._ensureScrollLockInterval);
            }
          }, 50);

          // Stop checking after 500ms (covers 200ms Phoenix modal hide animation)
          setTimeout(() => {
            if (window._ensureScrollLockInterval) {
              clearInterval(window._ensureScrollLockInterval);
            }
          }, 500);

          // If editMode is true or there's no name, go directly to edit mode
          if (editMode === true || editMode === 'true' || !currentName) {
            viewMode.classList.add('hidden');
            editModeEl.classList.remove('hidden');
            input.value = currentName;
            setTimeout(() => input.focus(), 100);
          } else {
            // Show view mode
            viewMode.classList.remove('hidden');
            editModeEl.classList.add('hidden');
          }
        };

        // Alias for opening in edit mode directly
        window.openUserSettingsModalEditMode = function() {
          window.openUserSettingsModal(true);
        };

        window.closeUserSettingsModal = function() {
          const modal = document.getElementById('user-settings-modal');
          // Clear the scroll lock interval if still running
          if (window._ensureScrollLockInterval) {
            clearInterval(window._ensureScrollLockInterval);
            window._ensureScrollLockInterval = null;
          }
          modal.classList.add('hidden');
          modal.classList.remove('flex');
          document.body.classList.remove('overflow-hidden');
        };

        window.startEditingUserName = function() {
          const viewMode = document.getElementById('user-name-view');
          const editMode = document.getElementById('user-name-edit');
          const input = document.getElementById('user-name-input');

          // Check if we're in acting_as mode
          const actingAs = window._actingAsParticipant;
          let currentName;

          if (actingAs) {
            currentName = actingAs.name;
          } else {
            currentName = localStorage.getItem('participant_name') || '';
          }

          // Load current name into input
          input.value = currentName;

          // Switch to edit mode
          viewMode.classList.add('hidden');
          editMode.classList.remove('hidden');

          // Focus input
          setTimeout(() => input.focus(), 50);
        };

        window.cancelEditingUserName = function() {
          const viewMode = document.getElementById('user-name-view');
          const editMode = document.getElementById('user-name-edit');

          // Check if we're in acting_as mode
          const actingAs = window._actingAsParticipant;
          const currentName = actingAs ? actingAs.name : (localStorage.getItem('participant_name') || '');

          // If there's no name, close modal instead
          if (!currentName) {
            window.closeUserSettingsModal();
            return;
          }

          // Switch back to view mode
          editMode.classList.add('hidden');
          viewMode.classList.remove('hidden');
        };

        window.saveUserSettings = function() {
          const input = document.getElementById('user-name-input');
          const newName = input.value.trim();
          const originalName = window._originalUserName;

          // Don't save empty names
          if (!newName) {
            input.focus();
            return;
          }

          // If name changed, dispatch custom event that the hook will listen to
          if (newName !== originalName) {
            // Dispatch custom event with name change data
            document.dispatchEvent(new CustomEvent('user-name-change-request', {
              detail: {
                old_name: originalName,
                new_name: newName,
                acting_as: window._actingAsParticipant ? true : false
              }
            }));

            // Close modal - the hook will handle the validation and response
            window.closeUserSettingsModal();
          } else {
            // Name didn't change, just close modal
            window.closeUserSettingsModal();
          }
        };

        // Handle Enter key in input
        document.addEventListener('DOMContentLoaded', function() {
          const input = document.getElementById('user-name-input');
          if (input) {
            input.addEventListener('keydown', function(e) {
              if (e.key === 'Enter') {
                e.preventDefault();
                window.saveUserSettings();
              } else if (e.key === 'Escape') {
                window.cancelEditingUserName();
              }
            });
          }
        });
      </script>
    </div>
    """
  end

  @doc """
  Language selector component for switching between supported locales.
  Displays as a dropdown menu using native HTML details/summary.
  """
  attr :locale, :string, required: true, doc: "current locale"
  attr :current_path, :string, required: true, doc: "current request path"

  @supported_locales [
    %{code: "en", name: "English", flag: "🇬🇧"},
    %{code: "es", name: "Español", flag: "🇪🇸"}
  ]

  def language_selector(assigns) do
    assigns = assign(assigns, :locales, @supported_locales)

    ~H"""
    <details class="relative group" id="language-dropdown">
      <summary class="flex items-center gap-1.5 px-2.5 py-1.5 bg-base-200 hover:bg-base-300 border border-base-300 rounded-lg transition-colors text-sm font-medium text-base-content cursor-pointer list-none select-none">
        <span class="text-base">{current_flag(@locale)}</span>
        <span class="hidden sm:inline">{String.upcase(@locale)}</span>
        <.icon
          name="hero-chevron-down"
          class="w-3.5 h-3.5 transition-transform group-open:rotate-180"
        />
      </summary>

      <div class="absolute right-0 mt-2 w-40 bg-base-300 border border-base-300 rounded-lg shadow-xl z-50 overflow-hidden">
        <%= for lang <- @locales do %>
          <%= if lang.code == @locale do %>
            <div class="flex items-center gap-2.5 px-3 py-2.5 bg-primary/10 text-base-content cursor-default">
              <span class="text-base">{lang.flag}</span>
              <span class="text-sm font-medium">{lang.name}</span>
              <.icon name="hero-check" class="w-4 h-4 ml-auto text-primary" />
            </div>
          <% else %>
            <a
              href={locale_path(@current_path, lang.code)}
              class="flex items-center gap-2.5 px-3 py-2.5 hover:bg-base-200 text-base-content transition-colors"
            >
              <span class="text-base">{lang.flag}</span>
              <span class="text-sm font-medium">{lang.name}</span>
            </a>
          <% end %>
        <% end %>
      </div>
    </details>
    """
  end

  defp current_flag("en"), do: "🇬🇧"
  defp current_flag("es"), do: "🇪🇸"
  defp current_flag(_), do: "🌐"

  @doc """
  Calculates the path for switching to a different locale.
  Replaces the locale segment in the current path while preserving the rest.
  """
  def locale_path(current_path, new_locale) do
    # Split path into segments, preserving empty first segment
    segments = String.split(current_path, "/")

    case segments do
      # Path like "/en/tickets/123" -> ["", "en", "tickets", "123"]
      ["", current_locale | rest] when current_locale in ["en", "es"] ->
        "/" <> new_locale <> "/" <> Enum.join(rest, "/")

      # Path like "/en/" -> ["", "en", ""]
      ["", current_locale, ""] when current_locale in ["en", "es"] ->
        "/" <> new_locale <> "/"

      # Path like "/en" -> ["", "en"]
      ["", current_locale] when current_locale in ["en", "es"] ->
        "/" <> new_locale <> "/"

      # Fallback
      _ ->
        "/" <> new_locale <> "/"
    end
  end

  defp app_version do
    Application.spec(:ticket_splitter, :vsn) |> to_string()
  end
end
