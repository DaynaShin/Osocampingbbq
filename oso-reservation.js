// OSO Camping BBQ 예약 시스템 JavaScript
// 새로운 카탈로그 기반 구조에 맞게 작성

let availableSlots = [];
let selectedDate = null;
let selectedSku = null;
let categoryPrices = {};

// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', function() {
    initializeReservationForm();
    setupEventListeners();
    setMinDate();
    loadCatalogData();
});

function initializeReservationForm() {
    const form = document.getElementById('reservationForm');
    if (form) form.reset();
    resetSubmitButton();
}

function resetSubmitButton() {
    const btn = document.getElementById('submitBtn');
    if (!btn) return;
    const text = btn.querySelector('.btn-text');
    const loader = btn.querySelector('.btn-loader');
    btn.disabled = false;
    if (text) text.style.display = 'inline';
    if (loader) loader.style.display = 'none';
}

function setupEventListeners() {
    const form = document.getElementById('reservationForm');
    const closeMessageBtn = document.getElementById('closeMessage');
    const datePickerBtn = document.getElementById('datePickerBtn');
    const guestCountSelect = document.getElementById('guest_count');
    const phoneInput = document.getElementById('phone');

    if (form) form.addEventListener('submit', handleFormSubmit);
    if (closeMessageBtn) closeMessageBtn.addEventListener('click', hideMessage);
    if (datePickerBtn) datePickerBtn.addEventListener('click', toggleDatePicker);
    if (guestCountSelect) guestCountSelect.addEventListener('change', handleGuestCountChange);
    if (phoneInput) phoneInput.addEventListener('input', formatPhoneNumber);

    // 달력 이벤트
    setupCalendarEvents();

    // 폼 필드 검증
    if (form) {
        const requiredFields = form.querySelectorAll('input[required], select[required]');
        requiredFields.forEach(field => field.addEventListener('blur', validateField));
    }
}

function setMinDate() {
    const today = new Date().toISOString().split('T')[0];
    const dateInput = document.getElementById('reservation_date');
    if (dateInput) {
        dateInput.min = today;
    }
}

// 카탈로그 데이터 로드
async function loadCatalogData() {
    try {
        const result = await getAvailableSlots();
        if (result.success && result.data) {
            availableSlots = result.data;
            
            // 카테고리별 가격 정보 저장
            result.data.forEach(slot => {
                if (!categoryPrices[slot.category_code]) {
                    categoryPrices[slot.category_code] = {
                        base_price: slot.base_price,
                        max_guests: slot.max_guests,
                        display_name: getCategoryDisplayName(slot.category_code)
                    };
                }
            });

            console.log('카탈로그 데이터 로드 완료:', availableSlots.length, '개 슬롯');
        } else {
            console.error('카탈로그 데이터 로드 실패:', result.error);
        }
    } catch (error) {
        console.error('카탈로그 데이터 로드 중 오류:', error);
    }
}

// 인원수 변경 시 처리
function handleGuestCountChange() {
    const guestCount = parseInt(document.getElementById('guest_count').value);
    if (guestCount && selectedDate) {
        updateVenueSelection(selectedDate, guestCount);
    }
}

// 달력 관련 함수들
function toggleDatePicker() {
    const popup = document.getElementById('calendarPopup');
    if (popup.style.display === 'none' || !popup.style.display) {
        showCalendar();
    } else {
        hideCalendar();
    }
}

function showCalendar() {
    const popup = document.getElementById('calendarPopup');
    popup.style.display = 'block';
    generateCalendar();
}

function hideCalendar() {
    const popup = document.getElementById('calendarPopup');
    popup.style.display = 'none';
}

function setupCalendarEvents() {
    const prevBtn = document.getElementById('prevMonth');
    const nextBtn = document.getElementById('nextMonth');
    
    if (prevBtn) prevBtn.addEventListener('click', () => changeMonth(-1));
    if (nextBtn) nextBtn.addEventListener('click', () => changeMonth(1));

    // 외부 클릭시 달력 숨기기
    document.addEventListener('click', function(event) {
        const calendar = document.getElementById('calendarPopup');
        const datePickerBtn = document.getElementById('datePickerBtn');
        
        if (!calendar.contains(event.target) && !datePickerBtn.contains(event.target)) {
            hideCalendar();
        }
    });
}

let currentMonth = new Date().getMonth();
let currentYear = new Date().getFullYear();

function generateCalendar() {
    const calendarDays = document.getElementById('calendarDays');
    const calendarTitle = document.getElementById('calendarTitle');
    
    const monthNames = ['1월', '2월', '3월', '4월', '5월', '6월',
                       '7월', '8월', '9월', '10월', '11월', '12월'];
    
    calendarTitle.textContent = `${currentYear}년 ${monthNames[currentMonth]}`;
    
    const firstDay = new Date(currentYear, currentMonth, 1).getDay();
    const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
    const today = new Date();
    
    let daysHTML = '';
    
    // 이전 달의 빈 칸들
    for (let i = 0; i < firstDay; i++) {
        daysHTML += '<div class="calendar-day empty"></div>';
    }
    
    // 현재 달의 날짜들
    for (let day = 1; day <= daysInMonth; day++) {
        const date = new Date(currentYear, currentMonth, day);
        const dateString = date.toISOString().split('T')[0];
        const isToday = date.toDateString() === today.toDateString();
        const isPast = date < today.setHours(0,0,0,0);
        const isSelected = dateString === selectedDate;
        
        let className = 'calendar-day';
        if (isToday) className += ' today';
        if (isPast) className += ' disabled';
        if (isSelected) className += ' selected';
        
        daysHTML += `<div class="${className}" data-date="${dateString}" onclick="selectDate('${dateString}')">${day}</div>`;
    }
    
    calendarDays.innerHTML = daysHTML;
}

function changeMonth(direction) {
    currentMonth += direction;
    if (currentMonth < 0) {
        currentMonth = 11;
        currentYear--;
    } else if (currentMonth > 11) {
        currentMonth = 0;
        currentYear++;
    }
    generateCalendar();
}

function selectDate(dateString) {
    const dateElement = document.querySelector(`[data-date="${dateString}"]`);
    if (dateElement && dateElement.classList.contains('disabled')) {
        return;
    }

    // 기존 선택 해제
    document.querySelectorAll('.calendar-day.selected').forEach(day => {
        day.classList.remove('selected');
    });
    
    // 새로운 날짜 선택
    dateElement.classList.add('selected');
    selectedDate = dateString;
    
    // UI 업데이트
    const selectedDateText = document.getElementById('selectedDateText');
    const dateInput = document.getElementById('reservation_date');
    const formattedDate = new Date(dateString).toLocaleDateString('ko-KR');
    
    selectedDateText.textContent = formattedDate;
    dateInput.value = dateString;
    
    // 달력 숨기기
    hideCalendar();
    
    // 인원수가 선택되어 있으면 장소 선택 업데이트
    const guestCount = parseInt(document.getElementById('guest_count').value);
    if (guestCount) {
        updateVenueSelection(dateString, guestCount);
    }
}

// 장소 선택 업데이트
async function updateVenueSelection(date, guestCount) {
    const venueSelection = document.getElementById('venueSelection');
    const venueGrid = document.getElementById('venueGrid');
    
    try {
        // 해당 날짜의 가용성 초기화 (필요한 경우)
        await initializeAvailability(date);
        
        // 가용한 슬롯들을 카테고리별로 그룹화
        const availableByCategory = {};
        
        availableSlots.forEach(slot => {
            if (slot.max_guests >= guestCount) {
                if (!availableByCategory[slot.category_code]) {
                    availableByCategory[slot.category_code] = {
                        category: getCategoryDisplayName(slot.category_code),
                        slots: []
                    };
                }
                availableByCategory[slot.category_code].slots.push(slot);
            }
        });
        
        // UI 생성
        let gridHTML = '';
        
        Object.entries(availableByCategory).forEach(([categoryCode, categoryData]) => {
            gridHTML += `
                <div class="category-section">
                    <h4 class="category-title">${categoryData.category}</h4>
                    <div class="time-slots">
            `;
            
            // 시간대별로 그룹화
            const timeSlots = {};
            categoryData.slots.forEach(slot => {
                if (!timeSlots[slot.slot_name]) {
                    timeSlots[slot.slot_name] = [];
                }
                timeSlots[slot.slot_name].push(slot);
            });
            
            Object.entries(timeSlots).forEach(([timeName, slots]) => {
                const firstSlot = slots[0];
                const timeRange = formatTimeSlot(firstSlot.start_local, firstSlot.end_local);
                // 새로운 동적 가격 계산 (추가 인원 요금 포함)
                const resourceData = {
                    price: firstSlot.base_price,
                    base_guests: firstSlot.base_guests || 4,
                    extra_guest_fee: firstSlot.extra_guest_fee || 0,
                    max_extra_guests: firstSlot.max_extra_guests || 0,
                    has_weekend_pricing: firstSlot.has_weekend_pricing || false
                };
                const timeSlotData = {
                    price_multiplier: firstSlot.time_slot_catalog?.price_multiplier || 1.0,
                    weekday_multiplier: firstSlot.time_slot_catalog?.weekday_multiplier || 1.0,
                    weekend_multiplier: firstSlot.time_slot_catalog?.weekend_multiplier || 1.2
                };
                
                const priceInfo = calculateDynamicPrice(resourceData, timeSlotData, selectedDate, guestCount);
                const price = priceInfo.finalPrice;
                
                // 인원 정보 표시
                const guestInfo = guestCount <= resourceData.base_guests ? 
                    `${guestCount}명` : 
                    `${guestCount}명 (기본 ${resourceData.base_guests}명 + 추가 ${priceInfo.extraGuests}명)`;
                
                // 주말 요금 표시 여부
                const weekendBadge = priceInfo.isWeekendRate ? '<span class="weekend-badge">주말요금</span>' : '';
                
                gridHTML += `
                    <div class="time-slot-card" onclick="selectTimeSlot('${categoryCode}', '${timeName}', '${timeRange}', ${JSON.stringify(priceInfo).replace(/"/g, '&quot;')})">
                        <div class="time-info">
                            <div class="time-range">${timeRange}</div>
                            <div class="time-name">${timeName}</div>
                        </div>
                        <div class="price-info">
                            <div class="guest-info">${guestInfo}</div>
                            <div class="price">₩${price.toLocaleString()} ${weekendBadge}</div>
                            ${priceInfo.extraGuests > 0 ? `<div class="extra-fee-info">추가 인원: ₩${priceInfo.extraGuestsFeeTotal.toLocaleString()}</div>` : ''}
                            <div class="available">${slots.length}개 가능</div>
                        </div>
                    </div>
                `;
            });
            
            gridHTML += `
                    </div>
                </div>
            `;
        });
        
        venueGrid.innerHTML = gridHTML;
        venueSelection.style.display = 'block';
        
    } catch (error) {
        console.error('장소 선택 업데이트 중 오류:', error);
        showMessage('장소 정보를 불러오는 중 오류가 발생했습니다.', 'error');
    }
}

// 시간 슬롯 선택
function selectTimeSlot(categoryCode, timeName, timeRange, price, isWeekendRate = false) {
    // 기존 선택 해제
    document.querySelectorAll('.time-slot-card.selected').forEach(card => {
        card.classList.remove('selected');
    });
    
    // 새로운 선택
    event.currentTarget.classList.add('selected');
    
    // 선택 정보 저장 (실제 SKU는 예약 시 결정)
    selectedSku = {
        categoryCode,
        timeName,
        timeRange,
        price,
        isWeekendRate
    };
    
    // 선택된 정보 표시
    updateSelectedVenueInfo();
}

function updateSelectedVenueInfo() {
    const infoContainer = document.getElementById('selectedVenueInfo');
    const infoContent = document.getElementById('venueInfoContent');
    
    if (selectedSku && selectedDate) {
        const guestCount = parseInt(document.getElementById('guest_count').value);
        const categoryName = getCategoryDisplayName(selectedSku.categoryCode);
        const priceInfo = selectedSku.priceInfo;
        
        const weekendBadge = priceInfo.isWeekendRate ? '<span class="weekend-badge">주말요금</span>' : '';
        const dateInfo = new Date(selectedDate);
        const isWeekendDate = isWeekend(selectedDate);
        const dayInfo = isWeekendDate ? ' (주말)' : ' (평일)';
        
        // 인원 정보 표시
        const guestDisplay = guestCount <= priceInfo.baseGuests ? 
            `${guestCount}명` : 
            `${guestCount}명 (기본 ${priceInfo.baseGuests}명 + 추가 ${priceInfo.extraGuests}명)`;
        
        // 가격 상세 정보
        let priceDetail = '';
        if (priceInfo.extraGuests > 0) {
            priceDetail = `
                <div class="price-breakdown">
                    <div>기본 요금: ₩${priceInfo.baseTotal.toLocaleString()}</div>
                    <div>추가 인원 요금: ₩${priceInfo.extraGuestsFeeTotal.toLocaleString()} (${priceInfo.extraGuests}명 × ₩${priceInfo.extraGuestFeePerPerson.toLocaleString()})</div>
                    <div class="total-price"><strong>총 요금: ₩${priceInfo.finalPrice.toLocaleString()} ${weekendBadge}</strong></div>
                </div>
            `;
        } else {
            priceDetail = `<div class="price-detail"><strong>예상 요금:</strong> ₩${priceInfo.finalPrice.toLocaleString()} ${weekendBadge}</div>`;
        }
        
        infoContent.innerHTML = `
            <div class="venue-detail">
                <div><strong>예약 날짜:</strong> ${dateInfo.toLocaleDateString('ko-KR')}${dayInfo}</div>
                <div><strong>장소 유형:</strong> ${categoryName}</div>
                <div><strong>시간:</strong> ${selectedSku.timeRange} (${selectedSku.timeName})</div>
                <div><strong>인원:</strong> ${guestDisplay}</div>
                ${priceDetail}
                ${priceInfo.isWeekendRate ? '<div class="weekend-notice">※ 주말 할증요금이 적용됩니다.</div>' : ''}
            </div>
        `;
        
        infoContainer.style.display = 'block';
    } else {
        infoContainer.style.display = 'none';
    }
}

// 폼 제출 처리
async function handleFormSubmit(event) {
    event.preventDefault();
    
    if (!validateForm()) return;
    
    const formData = new FormData(event.target);
    const submitBtn = document.getElementById('submitBtn');
    const btnText = submitBtn.querySelector('.btn-text');
    const btnLoader = submitBtn.querySelector('.btn-loader');
    
    // 제출 버튼 비활성화
    submitBtn.disabled = true;
    btnText.style.display = 'none';
    btnLoader.style.display = 'inline';
    
    try {
        // 사용 가능한 실제 SKU 찾기
        const actualSku = findAvailableSku(selectedDate, selectedSku.categoryCode, selectedSku.timeName);
        
        if (!actualSku) {
            throw new Error('선택하신 시간대에 예약 가능한 장소가 없습니다.');
        }
        
        const reservationData = {
            name: formData.get('name').trim(),
            phone: formData.get('phone').trim(),
            email: formData.get('email').trim() || null,
            reservation_date: selectedDate,
            sku_code: actualSku,
            guest_count: parseInt(formData.get('guest_count')),
            special_requests: formData.get('special_requests').trim() || null
        };
        
        const result = await createReservation(reservationData);
        
        if (result.success && result.data && result.data[0]) {
            const reservation = result.data[0];
            const reservationNumber = reservation.reservation_number;
            
            if (reservationNumber) {
                showMessage(`예약 신청이 완료되었습니다! 예약번호: ${reservationNumber}\n(예약번호와 전화번호로 예약 조회가 가능합니다)`, 'success');
            } else {
                showMessage('예약 신청이 완료되었습니다! 확인 후 연락드리겠습니다.', 'success');
            }
            
            event.target.reset();
            resetForm();
        } else {
            throw new Error(result.error || '예약 신청 중 오류가 발생했습니다.');
        }
        
    } catch (error) {
        console.error('예약 신청 오류:', error);
        showMessage(error.message || '예약 신청 중 오류가 발생했습니다.', 'error');
    } finally {
        submitBtn.disabled = false;
        btnText.style.display = 'inline';
        btnLoader.style.display = 'none';
    }
}

function findAvailableSku(date, categoryCode, timeName) {
    // 해당 카테고리와 시간대의 SKU 중 사용 가능한 것 찾기
    const matchingSlots = availableSlots.filter(slot => 
        slot.category_code === categoryCode && 
        slot.slot_name === timeName
    );
    
    // 간단히 첫 번째 매칭되는 SKU 반환 (실제로는 가용성 확인 필요)
    return matchingSlots.length > 0 ? matchingSlots[0].sku_code : null;
}

function validateForm() {
    const name = document.getElementById('name').value.trim();
    const phone = document.getElementById('phone').value.trim();
    const guestCount = document.getElementById('guest_count').value;
    
    if (!name) {
        showMessage('이름을 입력해주세요.', 'error');
        return false;
    }
    
    if (!phone) {
        showMessage('연락처를 입력해주세요.', 'error');
        return false;
    }
    
    if (!selectedDate) {
        showMessage('예약 날짜를 선택해주세요.', 'error');
        return false;
    }
    
    if (!guestCount) {
        showMessage('인원 수를 선택해주세요.', 'error');
        return false;
    }
    
    if (!selectedSku) {
        showMessage('장소와 시간을 선택해주세요.', 'error');
        return false;
    }
    
    return true;
}

function resetForm() {
    selectedDate = null;
    selectedSku = null;
    
    document.getElementById('selectedDateText').textContent = '날짜를 선택하세요';
    document.getElementById('venueSelection').style.display = 'none';
    document.getElementById('selectedVenueInfo').style.display = 'none';
    
    document.querySelectorAll('.calendar-day.selected').forEach(day => {
        day.classList.remove('selected');
    });
}

// 유틸리티 함수들
function validateField(event) {
    const field = event.target;
    const value = field.value.trim();
    
    if (field.required && !value) {
        field.classList.add('error');
    } else {
        field.classList.remove('error');
    }
}

function formatPhoneNumber(event) {
    let value = event.target.value.replace(/\D/g, '');
    if (value.length >= 11) {
        value = value.substring(0, 11);
        value = value.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    } else if (value.length >= 7) {
        value = value.replace(/(\d{3})(\d{3,4})(\d{0,4})/, '$1-$2-$3');
    } else if (value.length >= 4) {
        value = value.replace(/(\d{3})(\d{1,3})/, '$1-$2');
    }
    event.target.value = value;
}

function showMessage(message, type) {
    const container = document.getElementById('messageContainer');
    const content = document.getElementById('messageContent');
    
    content.textContent = message;
    container.className = `message-container ${type}`;
    container.style.display = 'flex';
}

function hideMessage() {
    const container = document.getElementById('messageContainer');
    container.style.display = 'none';
}