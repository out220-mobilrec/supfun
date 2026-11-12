import { Navigate, Route, Routes } from 'react-router-dom';
import Layout from './components/Layout';
import { RequireAuth, StaffGate } from './components/Guards';

import Login from './pages/Login';
import Register from './pages/Register';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';
import VerifyEmail from './pages/VerifyEmail';
import Dashboard from './pages/Dashboard';
import FeedPage from './pages/Feed';
import SearchPage from './pages/Search';
import EventsPage from './pages/Events';
import EventDetailPage from './pages/EventDetail';
import EventFormPage from './pages/EventForm';
import TracksPage from './pages/Tracks';
import TrackDetailPage from './pages/TrackDetail';
import TrackEditPage from './pages/TrackEdit';
import WaterbodiesPage from './pages/Waterbodies';
import WaterbodyDetailPage from './pages/WaterbodyDetail';
import MarketplacePage from './pages/Marketplace';
import ListingDetailPage from './pages/ListingDetail';
import ListingFormPage from './pages/ListingForm';
import MyListingsPage from './pages/MyListings';
import MyLeadsPage from './pages/MyLeads';
import UsersPage from './pages/Users';
import UserProfilePage from './pages/UserProfile';
import FriendsPage from './pages/Friends';
import NotificationsPage from './pages/Notifications';
import ProfilePage from './pages/Profile';
import ChatListPage from './pages/ChatList';
import ChatRoomPage from './pages/ChatRoom';
import ChannelsPage from './pages/Channels';
import ChannelDetailPage from './pages/ChannelDetail';
import NewsPage from './pages/News';
import NewsDetailPage from './pages/NewsDetail';
import GearPage from './pages/Gear';
import LeaderboardPage from './pages/Leaderboard';
import GamificationPage from './pages/Gamification';

import AdminDashboard from './pages/admin/AdminDashboard';
import AdminUsers from './pages/admin/AdminUsers';
import AdminListings from './pages/admin/AdminListings';
import AdminEvents from './pages/admin/AdminEvents';
import AdminEventsStats from './pages/admin/AdminEventsStats';
import AdminWaterbodies from './pages/admin/AdminWaterbodies';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route path="/forgot-password" element={<ForgotPassword />} />
      <Route path="/reset-password" element={<ResetPassword />} />
      <Route path="/verify-email" element={<VerifyEmail />} />

      <Route
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route path="/" element={<Dashboard />} />
        <Route path="/feed" element={<FeedPage />} />
        <Route path="/search" element={<SearchPage />} />
        <Route path="/notifications" element={<NotificationsPage />} />

        <Route path="/events" element={<EventsPage />} />
        <Route path="/events/new" element={<EventFormPage />} />
        <Route path="/events/:id" element={<EventDetailPage />} />
        <Route path="/events/:id/edit" element={<EventFormPage />} />

        <Route path="/tracks" element={<TracksPage />} />
        <Route path="/tracks/:id" element={<TrackDetailPage />} />
        <Route path="/tracks/:id/edit" element={<TrackEditPage />} />

        <Route path="/waterbodies" element={<WaterbodiesPage />} />
        <Route path="/waterbodies/:id" element={<WaterbodyDetailPage />} />

        <Route path="/marketplace" element={<MarketplacePage />} />
        <Route path="/marketplace/new" element={<ListingFormPage />} />
        <Route path="/marketplace/my" element={<MyListingsPage />} />
        <Route path="/marketplace/leads" element={<MyLeadsPage />} />
        <Route path="/marketplace/:id" element={<ListingDetailPage />} />
        <Route path="/marketplace/:id/edit" element={<ListingFormPage />} />

        <Route path="/users" element={<UsersPage />} />
        <Route path="/users/:id" element={<UserProfilePage />} />
        <Route path="/friends" element={<FriendsPage />} />

        <Route path="/chats" element={<ChatListPage />} />
        <Route path="/chats/:id" element={<ChatRoomPage />} />

        <Route path="/channels" element={<ChannelsPage />} />
        <Route path="/channels/:id" element={<ChannelDetailPage />} />
        <Route path="/news" element={<NewsPage />} />
        <Route path="/news/:id" element={<NewsDetailPage />} />
        <Route path="/gear" element={<GearPage />} />
        <Route path="/rating" element={<LeaderboardPage />} />
        <Route path="/gamification" element={<GamificationPage />} />

        <Route path="/profile" element={<ProfilePage />} />

        <Route path="/admin" element={<StaffGate><AdminDashboard /></StaffGate>} />
        <Route path="/admin/users" element={<StaffGate><AdminUsers /></StaffGate>} />
        <Route path="/admin/listings" element={<StaffGate><AdminListings /></StaffGate>} />
        <Route path="/admin/events" element={<StaffGate><AdminEvents /></StaffGate>} />
      <Route path="/admin/events/stats" element={<StaffGate><AdminEventsStats /></StaffGate>} />
        <Route path="/admin/waterbodies" element={<StaffGate><AdminWaterbodies /></StaffGate>} />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}