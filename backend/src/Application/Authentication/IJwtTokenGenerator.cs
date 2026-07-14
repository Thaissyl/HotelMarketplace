using HotelMarketplace.Application.Security;

namespace HotelMarketplace.Application.Authentication;

public interface IJwtTokenGenerator
{
    GeneratedJwtToken Generate(CurrentUser user);
}
