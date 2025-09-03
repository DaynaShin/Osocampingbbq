// 커스텀 달력 JavaScript

class CustomCalendar {
    constructor() {
        this.currentDate = new Date();
        this.selectedDate = null;
        this.today = new Date();
        
        this.monthNames = [
            '1월', '2월', '3월', '4월', '5월', '6월',
            '7월', '8월', '9월', '10월', '11월', '12월'
        ];
        
        this.init();
    }
    
    init() {
        this.bindEvents();
        this.render();
        this.setupOutsideClick();
    }
    
    bindEvents() {
        // 날짜 선택 버튼 클릭
        document.getElementById('datePickerBtn').addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleCalendar();
        });
        
        // 이전/다음 달 네비게이션
        document.getElementById('prevMonth').addEventListener('click', () => {
            this.previousMonth();
        });
        
        document.getElementById('nextMonth').addEventListener('click', () => {
            this.nextMonth();
        });
    }
    
    setupOutsideClick() {
        // 달력 외부 클릭 시 닫기
        document.addEventListener('click', (e) => {
            const calendar = document.getElementById('calendarPopup');
            const datePickerBtn = document.getElementById('datePickerBtn');
            
            if (!calendar.contains(e.target) && !datePickerBtn.contains(e.target)) {
                this.closeCalendar();
            }
        });
    }
    
    toggleCalendar() {
        const popup = document.getElementById('calendarPopup');
        const isVisible = popup.style.display === 'block';
        
        if (isVisible) {
            this.closeCalendar();
        } else {
            this.openCalendar();
        }
    }
    
    openCalendar() {
        document.getElementById('calendarPopup').style.display = 'block';
        this.render();
    }
    
    closeCalendar() {
        document.getElementById('calendarPopup').style.display = 'none';
    }
    
    previousMonth() {
        this.currentDate.setMonth(this.currentDate.getMonth() - 1);
        this.render();
    }
    
    nextMonth() {
        this.currentDate.setMonth(this.currentDate.getMonth() + 1);
        this.render();
    }
    
    render() {
        this.renderHeader();
        this.renderDays();
    }
    
    renderHeader() {
        const title = document.getElementById('calendarTitle');
        const year = this.currentDate.getFullYear();
        const month = this.currentDate.getMonth();
        
        title.textContent = `${year}년 ${this.monthNames[month]}`;
    }
    
    renderDays() {
        const daysContainer = document.getElementById('calendarDays');
        daysContainer.innerHTML = '';
        
        const year = this.currentDate.getFullYear();
        const month = this.currentDate.getMonth();
        
        // 이번 달 첫째 날과 마지막 날
        const firstDay = new Date(year, month, 1);
        const lastDay = new Date(year, month + 1, 0);
        
        // 첫째 주 시작 날짜 (일요일부터)
        const startDate = new Date(firstDay);
        startDate.setDate(startDate.getDate() - firstDay.getDay());
        
        // 6주 동안 렌더링 (42일)
        for (let i = 0; i < 42; i++) {
            const date = new Date(startDate);
            date.setDate(startDate.getDate() + i);
            
            const dayElement = this.createDayElement(date, month);
            daysContainer.appendChild(dayElement);
        }
    }
    
    createDayElement(date, currentMonth) {
        const dayDiv = document.createElement('div');
        dayDiv.className = 'calendar-day';
        dayDiv.textContent = date.getDate();
        
        // 다른 달의 날짜
        if (date.getMonth() !== currentMonth) {
            dayDiv.classList.add('other-month');
        }
        
        // 오늘 날짜
        if (this.isSameDay(date, this.today)) {
            dayDiv.classList.add('today');
        }
        
        // 선택된 날짜
        if (this.selectedDate && this.isSameDay(date, this.selectedDate)) {
            dayDiv.classList.add('selected');
        }
        
        // 과거 날짜 비활성화 (오늘 이전)
        if (date < this.today && !this.isSameDay(date, this.today)) {
            dayDiv.classList.add('disabled');
        } else if (date.getMonth() === currentMonth) {
            // 클릭 이벤트 추가 (현재 달의 유효한 날짜만)
            dayDiv.addEventListener('click', () => {
                this.selectDate(date);
            });
        }
        
        return dayDiv;
    }
    
    selectDate(date) {
        this.selectedDate = new Date(date);
        this.updateSelectedDateDisplay();
        this.updateHiddenInput();
        this.closeCalendar();
        
        // 선택된 날짜 알림 (요청된 기능)
        this.notifyDateSelection(date);
        
        // 해당 날짜의 예약 가능한 상품 조회
        this.loadAvailableProducts(date);
    }
    
    updateSelectedDateDisplay() {
        const selectedDateText = document.getElementById('selectedDateText');
        
        if (this.selectedDate) {
            const year = this.selectedDate.getFullYear();
            const month = this.selectedDate.getMonth() + 1;
            const day = this.selectedDate.getDate();
            const weekday = this.getWeekdayName(this.selectedDate.getDay());
            
            selectedDateText.innerHTML = `<span class="selected-date">${year}년 ${month}월 ${day}일 (${weekday})</span>`;
        } else {
            selectedDateText.textContent = '날짜를 선택하세요';
        }
    }
    
    updateHiddenInput() {
        const hiddenInput = document.getElementById('reservation_date');
        
        if (this.selectedDate) {
            const year = this.selectedDate.getFullYear();
            const month = String(this.selectedDate.getMonth() + 1).padStart(2, '0');
            const day = String(this.selectedDate.getDate()).padStart(2, '0');
            
            hiddenInput.value = `${year}-${month}-${day}`;
        } else {
            hiddenInput.value = '';
        }
    }
    
    notifyDateSelection(date) {
        const year = date.getFullYear();
        const month = date.getMonth() + 1;
        const day = date.getDate();
        const weekday = this.getWeekdayName(date.getDay());
        
        // 콘솔에 알림
        console.log(`선택된 날짜: ${year}년 ${month}월 ${day}일 (${weekday})`);
        
        // 사용자에게 알림 메시지 (선택사항)
        showMessage(`${year}년 ${month}월 ${day}일 (${weekday})이 선택되었습니다.`, 'success');
    }
    
    getWeekdayName(dayIndex) {
        const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
        return weekdays[dayIndex];
    }
    
    isSameDay(date1, date2) {
        return date1.getFullYear() === date2.getFullYear() &&
               date1.getMonth() === date2.getMonth() &&
               date1.getDate() === date2.getDate();
    }
    
    // 외부에서 날짜를 설정할 때 사용
    setDate(date) {
        this.selectedDate = new Date(date);
        this.currentDate = new Date(date);
        this.updateSelectedDateDisplay();
        this.updateHiddenInput();
        this.render();
    }
    
    // 선택된 날짜 가져오기
    getSelectedDate() {
        return this.selectedDate;
    }
    
    // 선택된 날짜를 문자열로 반환
    getSelectedDateString() {
        if (!this.selectedDate) return null;
        
        const year = this.selectedDate.getFullYear();
        const month = String(this.selectedDate.getMonth() + 1).padStart(2, '0');
        const day = String(this.selectedDate.getDate()).padStart(2, '0');
        
        return `${year}-${month}-${day}`;
    }
    
    // 해당 날짜의 예약 가능한 상품 조회
    async loadAvailableProducts(date) {
        const dateString = this.formatDateForAPI(date);
        
        try {
            // 예약 가능한 상품 조회
            const result = await getAvailableProductsByDate(dateString);
            
            if (result.success) {
                this.displayAvailableProducts(result.data, date);
            } else {
                console.error('예약 가능한 상품 조회 실패:', result.error);
                this.displayAvailableProducts([], date);
            }
        } catch (error) {
            console.error('예약 가능한 상품 조회 오류:', error);
            this.displayAvailableProducts([], date);
        }
    }
    
    // 날짜를 API용 문자열로 포맷팅
    formatDateForAPI(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        
        return `${year}-${month}-${day}`;
    }
    
    // 예약 가능한 상품 표시
    displayAvailableProducts(products, selectedDate) {
        const container = document.getElementById('availableProductsContainer');
        
        if (!container) {
            // 컨테이너가 없으면 동적으로 생성
            this.createAvailableProductsContainer();
            return this.displayAvailableProducts(products, selectedDate);
        }
        
        const year = selectedDate.getFullYear();
        const month = selectedDate.getMonth() + 1;
        const day = selectedDate.getDate();
        const weekday = this.getWeekdayName(selectedDate.getDay());
        
        if (!products || products.length === 0) {
            container.innerHTML = `
                <div class="available-products-section">
                    <div class="date-header">
                        <h3>${year}년 ${month}월 ${day}일 (${weekday}) 예약 현황</h3>
                    </div>
                    <div class="no-products">
                        <div class="no-products-icon">😔</div>
                        <p>해당 날짜에 예약 가능한 상품이 없습니다.</p>
                        <small>다른 날짜를 선택해 보세요.</small>
                    </div>
                </div>
            `;
        } else {
            const productsHTML = products.map(product => `
                <div class="product-item" data-product-id="${product.id}">
                    <div class="product-time">
                        ${this.formatTimeRange(product.start_time, product.end_time)}
                    </div>
                    <div class="product-info">
                        <h4>${product.product_name}</h4>
                        <p class="product-description">${product.description || '상품 설명이 없습니다.'}</p>
                        <div class="product-price">₩${product.price.toLocaleString()}</div>
                    </div>
                    <div class="product-actions">
                        <button class="select-product-btn" onclick="selectProduct('${product.id}', '${product.product_name}')">
                            선택하기
                        </button>
                    </div>
                </div>
            `).join('');
            
            container.innerHTML = `
                <div class="available-products-section">
                    <div class="date-header">
                        <h3>${year}년 ${month}월 ${day}일 (${weekday}) 예약 가능한 상품</h3>
                        <span class="product-count">${products.length}개 상품 이용 가능</span>
                    </div>
                    <div class="products-list">
                        ${productsHTML}
                    </div>
                </div>
            `;
        }
        
        // 컨테이너 표시
        container.style.display = 'block';
        
        // 부드럽게 스크롤
        container.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
    
    // 예약 가능한 상품 표시 컨테이너 동적 생성
    createAvailableProductsContainer() {
        const formContainer = document.querySelector('.form-container');
        
        if (formContainer) {
            const container = document.createElement('div');
            container.id = 'availableProductsContainer';
            container.style.display = 'none';
            
            // 폼 다음에 삽입
            formContainer.parentNode.insertBefore(container, formContainer.nextSibling);
        }
    }
    
    // 시간 범위 포맷팅
    formatTimeRange(startTime, endTime) {
        const formatTime = (timeString) => {
            const [hours, minutes] = timeString.split(':');
            const hour = parseInt(hours);
            const ampm = hour >= 12 ? '오후' : '오전';
            const displayHour = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
            return `${ampm} ${displayHour}:${minutes}`;
        };
        
        return `${formatTime(startTime)} - ${formatTime(endTime)}`;
    }
}

// 달력 인스턴스 생성 (페이지 로드 후)
let customCalendar;

// DOM이 로드된 후 달력 초기화
document.addEventListener('DOMContentLoaded', function() {
    // 달력 HTML이 존재하는 경우에만 초기화
    if (document.getElementById('datePickerBtn')) {
        customCalendar = new CustomCalendar();
        
        // 전역 함수로 달력 접근 가능하게 설정
        window.getSelectedDate = () => customCalendar.getSelectedDate();
        window.getSelectedDateString = () => customCalendar.getSelectedDateString();
        window.setCalendarDate = (date) => customCalendar.setDate(date);
    }
});

// 유틸리티 함수: 오늘 날짜부터 선택 가능하도록 설정
function setMinDateToToday() {
    if (customCalendar) {
        customCalendar.today = new Date();
        customCalendar.render();
    }
}