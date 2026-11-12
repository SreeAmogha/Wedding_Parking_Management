const sidebarHTML = `
    <aside class="sidebar">
        <div class="sidebar-brand">
            <span class="brand-icon">🚗</span>
            <div>
                <h2>Smart Parking</h2>
                <p>WEDDING MANAGEMENT</p>
            </div>
        </div>

        <nav class="sidebar-nav">
            <a href="dashboard.html" data-page="dashboard">
                <span>▦</span> Dashboard
            </a>

            <a href="entry-exit.html" data-page="entry-exit">
                <span>🚘</span> Entry / Exit
            </a>

            <a href="parking-slots.html" data-page="parking-slots">
                <span>🅿</span> Parking Slots
            </a>

            <a href="history.html" data-page="history">
                <span>◷</span> Parking History
            </a>

            <a href="events.html" data-page="events">
                <span>📅</span> Manage Events
            </a>
        </nav>

        <div class="sidebar-footer">
            <p>Smart Wedding Parking</p>
            <small id="sidebar-role-label">Staff Panel</small>
        </div>
    </aside>
`;

function renderSidebar() {
    const container = document.getElementById("sidebar-container");
    if (!container) return;

    container.innerHTML = sidebarHTML;

    // Determine current page from filename
    const path = window.location.pathname.toLowerCase();
    const filename = path.split('/').pop() || 'dashboard.html';

    let currentPage = 'dashboard';
    if (filename.includes('entry-exit'))         currentPage = 'entry-exit';
    else if (filename.includes('parking-slots'))  currentPage = 'parking-slots';
    else if (filename.includes('history'))        currentPage = 'history';
    else if (filename.includes('events'))         currentPage = 'events';

    const activeLink = container.querySelector(`[data-page="${currentPage}"]`);
    if (activeLink) activeLink.classList.add('active');

    // Dynamically update role label in footer if available
    try {
        import("./app.js").then(mod => {
            if (!mod || !mod.supabase) return;
            mod.supabase.auth.getSession().then(({ data }) => {
                const session = data && data.session;
                if (!session) return;
                mod.supabase
                    .from("profiles")
                    .select("role")
                    .eq("id", session.user.id)
                    .single()
                    .then(({ data: profile }) => {
                        const footerRole = document.getElementById("sidebar-role-label");
                        if (footerRole && profile) {
                            if (profile.role === "admin") footerRole.textContent = "Administrator Panel";
                            else if (profile.role === "manager") footerRole.textContent = "Manager Panel";
                            else footerRole.textContent = "Attendant Panel";
                        }
                    }).catch(() => {});
            }).catch(() => {});
        }).catch(() => {});
    } catch (e) {}
}

if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderSidebar);
} else {
    renderSidebar();
}
