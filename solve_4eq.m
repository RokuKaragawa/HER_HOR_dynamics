digits(32);
A_sym = sym([1, 1, 1, 1;
             4.018e-10, -3.756e7, 2.406e12, 0;
             0, 3.756e7, -2.406e12, 2.710e11;
             1.874e-14, 0, 1.093e7, -2.710e11]);
b_sym = sym([1; 0; 0; 0]);
x_sym = A_sym \ b_sym;
x_high = double(x_sym);

fprintf('方程组的四个解为（科学计数法）：\n');
for i = 1:4
    fprintf('x%d = %.15e\n', i, x_high(i));
end