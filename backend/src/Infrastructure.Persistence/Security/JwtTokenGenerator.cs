using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using HotelMarketplace.Application.Authentication;
using HotelMarketplace.Application.Security;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace HotelMarketplace.Infrastructure.Persistence.Security;

internal sealed class JwtTokenGenerator : IJwtTokenGenerator
{
    private readonly JwtOptions _jwtOptions;

    public JwtTokenGenerator(IOptions<JwtOptions> jwtOptions)
    {
        _jwtOptions = jwtOptions.Value;
    }

    public GeneratedJwtToken Generate(CurrentUser user)
    {
        DateTime expiresAtUtc = DateTime.UtcNow.AddMinutes(_jwtOptions.ExpirationMinutes);
        SymmetricSecurityKey signingKey = new(Encoding.UTF8.GetBytes(_jwtOptions.SigningKey));
        SigningCredentials signingCredentials = new(signingKey, SecurityAlgorithms.HmacSha256);

        List<Claim> claims = new()
        {
            new(SecurityClaimTypes.UserId, user.UserId.ToString()),
            new(SecurityClaimTypes.Email, user.Email),
            new(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        claims.AddRange(user.Roles.Select(role => new Claim(SecurityClaimTypes.Role, role.ToString())));
        claims.AddRange(user.HotelIds.Select(hotelId => new Claim(SecurityClaimTypes.HotelId, hotelId.ToString())));

        JwtSecurityToken token = new(
            issuer: _jwtOptions.Issuer,
            audience: _jwtOptions.Audience,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: expiresAtUtc,
            signingCredentials: signingCredentials);

        return new GeneratedJwtToken(new JwtSecurityTokenHandler().WriteToken(token), expiresAtUtc);
    }
}
