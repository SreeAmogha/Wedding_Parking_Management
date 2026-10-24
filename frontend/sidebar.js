
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
            <a href="/" data-page="dashboard">
                <span>▦</span> Dashboard
            </a>

            <a href="/history" data-page="history">
                <span>◷</span> Parking History
            </a>

            <a href="/events" data-page="events">
                <span>▣</span> Manage Events
            </a>

            <a href="/parking-slots" data-page="parking-slots">
                <span>🅿</span> Assign Parking Spots
            </a>
        </nav>

        <div class="sidebar-footer">
            <p>Smart Wedding Parking</p>
            <small>Attendant Panel</small>
        </div>
    </aside>
`;

document.addEventListener("DOMContentLoaded", () => {
    const container = document.getElementById("sidebar-container");

    if (!container) return;

    container.innerHTML = sidebarHTML;

    const currentPath = window.location.pathname;

    let currentPage = "dashboard";

    if (currentPath === "/history") {
        currentPage = "history";
    } else if (currentPath === "/events") {
        currentPage = "events";
    } else if (currentPath === "/parking-slots") {
        currentPage = "parking-slots";
    }

    const activeLink = container.querySelector(
        `[data-page="${currentPage}"]`
    );

    if (activeLink) {
        activeLink.classList.add("active");
    }
});
