namespace HotelMarketplace.SharedKernel.Tenancy;

public sealed class CurrentHotelContext : ICurrentHotelContext
{
    private HotelScope? _currentScope;

    public Guid? HotelId => _currentScope?.HotelId;

    public bool IsHotelScopeEnforced => _currentScope is not null;

    public IDisposable UseHotel(Guid hotelId)
    {
        HotelScope? previousScope = _currentScope;
        _currentScope = new HotelScope(hotelId);

        return new ScopeReset(() => _currentScope = previousScope);
    }

    private sealed record HotelScope(Guid HotelId);

    private sealed class ScopeReset : IDisposable
    {
        private readonly Action _reset;
        private bool _isDisposed;

        public ScopeReset(Action reset)
        {
            _reset = reset;
        }

        public void Dispose()
        {
            if (_isDisposed)
            {
                return;
            }

            _reset();
            _isDisposed = true;
        }
    }
}
