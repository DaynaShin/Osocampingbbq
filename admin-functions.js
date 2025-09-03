// 관리자 페이지 전용 함수들

// 최근 예약 표시 (대시보드용)
function displayRecentReservations(reservations) {
    const tbody = document.getElementById('recentReservationsTable');
    
    if (!reservations || reservations.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">예약이 없습니다.</td></tr>';
        // 대시보드의 빈 상태는 loadDashboardStats에서 처리
        return;
    }
    
    tbody.innerHTML = reservations.map(reservation => `
        <tr onclick="showReservationDetails('${reservation.id}')">
            <td>${formatDate(reservation.reservation_date)}</td>
            <td>${formatTime(reservation.reservation_time)}</td>
            <td>${reservation.name}</td>
            <td>${reservation.phone}</td>
            <td>${reservation.service_type || '-'}</td>
            <td><span class="status-badge ${reservation.status}">${getStatusText(reservation.status)}</span></td>
        </tr>
    `).join('');
}

// 전체 예약 목록 표시
function displayReservations(reservations) {
    const tbody = document.getElementById('reservationsTable');
    
    if (!reservations || reservations.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" class="text-center">예약이 없습니다.</td></tr>';
        toggleEmptyState('reservations', true);
        return;
    }
    
    toggleEmptyState('reservations', false);
    
    tbody.innerHTML = reservations.map(reservation => `
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
                    <button class="action-btn" onclick="showReservationDetails('${reservation.id}')" 
                            style="background: #4facfe; color: white;">상세</button>
                    ${reservation.status === 'pending' ? 
                        `<button class="action-btn confirm" onclick="confirmReservation('${reservation.id}')">확정</button>` : ''}
                    ${reservation.status !== 'cancelled' ? 
                        `<button class="action-btn cancel" onclick="cancelReservation('${reservation.id}')">취소</button>` : ''}
                    <button class="action-btn delete" onclick="deleteReservationConfirm('${reservation.id}')">삭제</button>
                </div>
            </td>
        </tr>
    `).join('');
}

// 예약 상세 정보 모달 표시
async function showReservationDetails(reservationId) {
    try {
        const result = await getReservationById(reservationId);
        if (result.success && result.data) {
            const reservation = result.data;
            const modalBody = document.getElementById('modalBody');
            
            modalBody.innerHTML = `
                <div style="line-height: 1.8;">
                    <p><strong>예약 ID:</strong> ${reservation.id}</p>
                    <p><strong>고객명:</strong> ${reservation.name}</p>
                    <p><strong>연락처:</strong> ${reservation.phone}</p>
                    <p><strong>이메일:</strong> ${reservation.email || '-'}</p>
                    <p><strong>예약일:</strong> ${formatDate(reservation.reservation_date)} (${getDayOfWeek(reservation.reservation_date)})</p>
                    <p><strong>예약시간:</strong> ${formatTime(reservation.reservation_time)}</p>
                    <p><strong>서비스 종류:</strong> ${reservation.service_type || '-'}</p>
                    <p><strong>상태:</strong> <span class="status-badge ${reservation.status}">${getStatusText(reservation.status)}</span></p>
                    <p><strong>요청사항:</strong></p>
                    <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; margin-top: 10px; white-space: pre-wrap;">
                        ${reservation.message || '요청사항이 없습니다.'}
                    </div>
                    <p style="margin-top: 15px;"><strong>신청일:</strong> ${formatDateTime(reservation.created_at)}</p>
                    ${reservation.updated_at && reservation.updated_at !== reservation.created_at ? 
                        `<p><strong>수정일:</strong> ${formatDateTime(reservation.updated_at)}</p>` : ''}
                </div>
            `;
            
            document.getElementById('reservationModal').style.display = 'block';
        }
    } catch (error) {
        console.error('예약 상세 정보 로드 오류:', error);
        showAdminMessage('예약 정보를 불러오는 중 오류가 발생했습니다.', 'error');
    }
}

// 예약 확정
function confirmReservation(reservationId) {
    currentReservationId = reservationId;
    currentAction = 'confirm';
    
    document.getElementById('confirmMessage').innerHTML = `
        <p>이 예약을 <strong>확정</strong>하시겠습니까?</p>
        <p style="color: #666; font-size: 0.9rem; margin-top: 10px;">확정된 예약은 고객에게 알림이 발송됩니다.</p>
    `;
    
    document.getElementById('confirmButton').onclick = executeConfirm;
    document.getElementById('confirmModal').style.display = 'block';
}

// 예약 취소
function cancelReservation(reservationId) {
    currentReservationId = reservationId;
    currentAction = 'cancel';
    
    document.getElementById('confirmMessage').innerHTML = `
        <p>이 예약을 <strong>취소</strong>하시겠습니까?</p>
        <p style="color: #666; font-size: 0.9rem; margin-top: 10px;">취소된 예약은 복구할 수 있습니다.</p>
    `;
    
    document.getElementById('confirmButton').onclick = executeConfirm;
    document.getElementById('confirmModal').style.display = 'block';
}

// 예약 삭제 확인
function deleteReservationConfirm(reservationId) {
    currentReservationId = reservationId;
    currentAction = 'delete';
    
    document.getElementById('confirmMessage').innerHTML = `
        <p style="color: #dc3545;"><strong>주의:</strong> 이 예약을 완전히 <strong>삭제</strong>하시겠습니까?</p>
        <p style="color: #666; font-size: 0.9rem; margin-top: 10px;">삭제된 데이터는 복구할 수 없습니다.</p>
    `;
    
    document.getElementById('confirmButton').onclick = executeConfirm;
    document.getElementById('confirmModal').style.display = 'block';
}

// 확인 액션 실행
async function executeConfirm() {
    try {
        let result;
        let message;
        
        switch (currentAction) {
            case 'confirm':
                result = await updateReservation(currentReservationId, { status: 'confirmed' });
                message = '예약이 확정되었습니다.';
                break;
            case 'cancel':
                result = await updateReservation(currentReservationId, { status: 'cancelled' });
                message = '예약이 취소되었습니다.';
                break;
            case 'delete':
                result = await deleteReservation(currentReservationId);
                message = '예약이 삭제되었습니다.';
                break;
        }
        
        if (result.success) {
            showAdminMessage(message, 'success');
            loadReservations();
            loadDashboardStats();
        } else {
            throw new Error(result.error);
        }
        
    } catch (error) {
        console.error('액션 실행 오류:', error);
        showAdminMessage('작업 중 오류가 발생했습니다.', 'error');
    } finally {
        closeConfirmModal();
    }
}

// 모달 닫기
function closeModal() {
    document.getElementById('reservationModal').style.display = 'none';
}

function closeConfirmModal() {
    document.getElementById('confirmModal').style.display = 'none';
    currentReservationId = null;
    currentAction = null;
}

// 상태 텍스트 변환
function getStatusText(status) {
    const statusMap = {
        'pending': '대기 중',
        'confirmed': '확정',
        'cancelled': '취소'
    };
    return statusMap[status] || status;
}

// 요일 구하기
function getDayOfWeek(dateString) {
    const days = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];
    const date = new Date(dateString);
    return days[date.getDay()];
}

// 날짜시간 포맷팅
function formatDateTime(dateTimeString) {
    const date = new Date(dateTimeString);
    return date.toLocaleString('ko-KR', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// CSV 내보내기
function exportToCSV() {
    // 구현 예정
    showAdminMessage('CSV 내보내기 기능 준비 중입니다.', 'info');
}

// 예약 통계 차트 (향후 구현 예정)
function generateChart() {
    // Chart.js 등을 사용하여 구현 예정
    showAdminMessage('차트 기능 준비 중입니다.', 'info');
}