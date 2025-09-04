// 관리자 페이지 보조 함수 (orig: 문자열 손상 복구 버전)

function displayRecentReservations(reservations) {
  const tbody = document.getElementById('recentReservationsTable');
  if (!tbody) return;

  if (!reservations || reservations.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" class="text-center">예약이 없습니다.</td></tr>';
    return;
  }

  tbody.innerHTML = reservations
    .map(
      (reservation) => `
      <tr onclick="showReservationDetails('${reservation.id}')">
        <td>${formatDate(reservation.reservation_date)}</td>
        <td>${formatTime(reservation.reservation_time)}</td>
        <td>${reservation.name}</td>
        <td>${reservation.phone}</td>
        <td>${reservation.service_type || '-'}</td>
        <td><span class="status-badge ${reservation.status}">${getStatusText(reservation.status)}</span></td>
      </tr>`
    )
    .join('');
}

function displayReservations(reservations) {
  const tbody = document.getElementById('reservationsTable');
  if (!tbody) return;

  if (!reservations || reservations.length === 0) {
    tbody.innerHTML = '<tr><td colspan="9" class="text-center">예약이 없습니다.</td></tr>';
    toggleEmptyState('reservations', true);
    return;
  }
  toggleEmptyState('reservations', false);

  tbody.innerHTML = reservations
    .map(
      (reservation) => `
      <tr>
        <td>${reservation.id.substring(0, 8)}...</td>
        <td>${formatDate(reservation.reservation_date)}</td>
        <td>${formatTime(reservation.reservation_time)}</td>
        <td>${reservation.name}</td>
        <td>${reservation.phone}</td>
        <td>${reservation.email || '-'}</td>
        <td>${reservation.service_type || '-'}</td>
        <td><span class="status-badge ${reservation.status}">${getStatusText(reservation.status)}</span></td>
        <td>
          <div class="action-buttons">
            <button class="action-btn" onclick="showReservationDetails('${reservation.id}')" style="background:#4facfe;color:#fff;">상세</button>
            ${reservation.status === 'pending' ? `<button class="action-btn confirm" onclick="confirmReservation('${reservation.id}')">확정</button>` : ''}
            ${reservation.status !== 'cancelled' ? `<button class="action-btn cancel" onclick="cancelReservation('${reservation.id}')">취소</button>` : ''}
            <button class="action-btn delete" onclick="deleteReservationConfirm('${reservation.id}')">삭제</button>
          </div>
        </td>
      </tr>`
    )
    .join('');
}

async function showReservationDetails(reservationId) {
  try {
    const result = await getReservationById(reservationId);
    if (result.success && result.data) {
      const r = result.data;
      const modalBody = document.getElementById('modalBody');
      if (!modalBody) return;
      modalBody.innerHTML = `
        <div style="line-height:1.8;">
          <p><strong>예약 ID:</strong> ${r.id}</p>
          <p><strong>고객명:</strong> ${r.name}</p>
          <p><strong>연락처:</strong> ${r.phone}</p>
          <p><strong>이메일:</strong> ${r.email || '-'}</p>
          <p><strong>예약일:</strong> ${formatDate(r.reservation_date)} (${getDayOfWeek(r.reservation_date)})</p>
          <p><strong>예약시간:</strong> ${formatTime(r.reservation_time)}</p>
          <p><strong>서비스 종류:</strong> ${r.service_type || '-'}</p>
          <p><strong>상태:</strong> <span class="status-badge ${r.status}">${getStatusText(r.status)}</span></p>
          <p><strong>요청사항:</strong></p>
          <div style="background:#f8f9fa;padding:15px;border-radius:8px;margin-top:10px;white-space:pre-wrap;">${r.message || '요청사항이 없습니다.'}</div>
          <p style="margin-top:15px;"><strong>요청일:</strong> ${formatDateTime(r.created_at)}</p>
          ${r.updated_at && r.updated_at !== r.created_at ? `<p><strong>수정일:</strong> ${formatDateTime(r.updated_at)}</p>` : ''}
        </div>`;
      document.getElementById('reservationModal').style.display = 'block';
    }
  } catch (err) {
    console.error('예약 상세 로드 오류:', err);
    showAdminMessage('예약 정보를 불러오는 중 오류가 발생했습니다.', 'error');
  }
}

function getStatusText(status) {
  const map = { pending: '대기', confirmed: '확정', cancelled: '취소' };
  return map[status] || status;
}

function getDayOfWeek(dateString) {
  const days = ['일', '월', '화', '수', '목', '금', '토'];
  const date = new Date(dateString);
  return days[date.getDay()];
}

function formatDate(dateStr) {
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) return dateStr;
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function formatTime(timeStr) {
  if (!timeStr) return '';
  const [h, m] = String(timeStr).split(':');
  const hour = parseInt(h, 10);
  const ampm = hour >= 12 ? '오후' : '오전';
  const displayHour = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
  return `${ampm} ${displayHour}:${m}`;
}

function formatDateTime(dateTimeString) {
  const date = new Date(dateTimeString);
  try {
    return date.toLocaleString('ko-KR', {
      year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
    });
  } catch (_) {
    return dateTimeString;
  }
}

// 관리자 메시지 표시/숨김 (admin.html 인라인 스크립트와 동일 동작 가정)
function showAdminMessage(text, type = 'success') {
  const messageContainer = document.getElementById('adminMessageContainer');
  const messageContent = document.getElementById('adminMessageContent');
  if (!messageContainer || !messageContent) return;
  messageContent.textContent = text;
  messageContent.className = `message ${type}`;
  messageContainer.style.display = 'block';
  setTimeout(() => hideAdminMessage(), 5000);
}

function hideAdminMessage() {
  const c = document.getElementById('adminMessageContainer');
  if (c) c.style.display = 'none';
}

// 빈 상태 토글 (admin.html 인라인 스크립트가 사용하는 형태 유지)
function toggleEmptyState(sectionType, isEmpty) {
  let emptyStateId, tableId;
  switch (sectionType) {
    case 'dashboard':
      emptyStateId = 'dashboardEmptyState';
      tableId = 'recentReservationsTable';
      break;
    case 'reservations':
      emptyStateId = 'reservationsEmptyState';
      tableId = 'reservationsTable';
      break;
    case 'bookings':
      emptyStateId = 'bookingsEmptyState';
      tableId = 'bookingsTable';
      break;
    default:
      return;
  }
  const emptyState = document.getElementById(emptyStateId);
  const table = document.getElementById(tableId);
  if (isEmpty) {
    if (emptyState) emptyState.style.display = 'block';
    if (table && table.closest('.table-container')) table.closest('.table-container').style.display = 'none';
  } else {
    if (emptyState) emptyState.style.display = 'none';
    if (table && table.closest('.table-container')) table.closest('.table-container').style.display = 'block';
  }
}

// 전역 노출 (admin.html에서 호출)
window.displayRecentReservations = displayRecentReservations;
window.displayReservations = displayReservations;
window.showReservationDetails = showReservationDetails;
window.getStatusText = getStatusText;
window.getDayOfWeek = getDayOfWeek;
window.formatDate = formatDate;
window.formatTime = formatTime;
window.formatDateTime = formatDateTime;
window.toggleEmptyState = toggleEmptyState;
window.showAdminMessage = showAdminMessage;
window.hideAdminMessage = hideAdminMessage;

